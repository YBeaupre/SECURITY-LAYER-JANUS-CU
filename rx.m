%+------------------------------------------------------------------------+
%| JANUS is a simple, robust, open standard signalling method for         |
%| underwater communications. See <http://www.januswiki.org> for details. |
%+------------------------------------------------------------------------+
%| Example software implementations provided by STO CMRE are subject to   |
%| Copyright (C) 2008-2018 STO Centre for Maritime Research and           |
%| Experimentation (CMRE)                                                 |
%|                                                                        |
%| This is free software: you can redistribute it and/or modify it        |
%| under the terms of the GNU General Public License version 3 as         |
%| published by the Free Software Foundation.                             |
%|                                                                        |
%| This program is distributed in the hope that it will be useful, but    |
%| WITHOUT ANY WARRANTY; without even the implied warranty of FITNESS     |
%| FOR A PARTICULAR PURPOSE. See the GNU General Public License for       |
%| more details.                                                          |
%|                                                                        |
%| You should have received a copy of the GNU General Public License      |
%| along with this program. If not, see <http://www.gnu.org/licenses/>.   |
%+------------------------------------------------------------------------+
%| Authors: Ricardo Martins, Giovanni Zappa, Luigi Elia D'Amaro           |
%+------------------------------------------------------------------------+
%
% RX Interface to decode a JANUS waveform.
%
% Inputs:
%    pset       Parameter set structure.
%    bband      Complex baseband waveform.
%    bband_fs   Baseband sampling frequency (Hz).
%    params     Optional parameters.
%
% Outputs:
%    pkt        Decoded packet structure.
%    pkt_bytes  Unprocessed packet bytes.
%    state      Structure with info from the decoder.
%
% Remarks:
%    Set global variable verbose different from 0 to plot various
%    debugging informations.

function [pkt, pkt_bytes, state] = rx(pset, bband, bband_fs, params)
    import java.security.*;
    import java.math.*;
    import java.lang.String;
    import java.lang.*;
    global verbose;

    rx_path = fileparts(mfilename('fullpath'));
    addpath([rx_path '/plugins']);

    defaults;
    
    if (nargin < 3)
        params = parameters();
    end

    verbose = params.verbose;

    %% Initialize output variables to sane values.
    pkt = {};
    pkt_bytes = [];
    state = {};
    state.pset_id = pset.id;
    state.pset_name = pset.name;
    state.cfreq = pset.cfreq;
    state.bwidth = pset.bwidth;
    state.chip_frq = pset.chip_frq;
    state.chip_dur = pset.chip_dur;
    state.prim_q = pset.prim_q;
    state.prim_a = pset.prim_a;
    state.nblock = pset.nblock;
    state.pkt_idx = 0;
    state.crg_idx = 0;
    state.pkt_raw_bits = [];
    state.pkt_dec_bits = [];
    state.crg_raw_bits = [];
    state.crg_dec_bits = [];

    % Number of samples in a chip.
    chip_nsample = round(pset.chip_dur * bband_fs);
    
    %% Search 32 chips.
    pkt_nchip = ALPHABET_SIZE * (PKT_MIN_NBIT + CONV_ENC_MEM);
    slots = hop_pattern(pset.prim_a, pset.prim_q, 32 + pkt_nchip);

    % Chip oversampling.
    chip_oversampling = 4;

    % Max Doppler speed.
    if (~params.doppler_correction)
        max_speed = 0;
    else
        max_speed = params.doppler_max_speed;
    end

    [ freq_vec, chip_order ] = detector_parameters(params, pset, slots(1 : 32));
    [ chip_corr, align_delay ] = chips_alignment(bband, bband_fs, pset.chip_dur, chip_oversampling, freq_vec, chip_order, max_speed);
    
    cfar_mov_avg_time = .150;
    cfar_mov_avg = max(cfar_mov_avg_time, 26 * pset.chip_dur);
    step_l = fix(cfar_mov_avg * chip_oversampling / pset.chip_dur);

    guard_time = chip_oversampling * params.pset_chip_len_mul; % one chip

    % Todo: choose the optimal threshold.
    threshold = 2.5;

    d_istart = step_l + guard_time +1;
    d_istop = length(chip_corr);

    if (d_istart >= d_istop)
        error('janus:rx:nosig', 'no signal detected');
    end

    % Detection.
    offs_detector = detect_first(chip_corr, threshold, step_l, chip_oversampling, guard_time);

    % Converting oversampled chip in baseband index and time.
    offs = fix(offs_detector * chip_nsample / chip_oversampling + align_delay * bband_fs);

    state.after = offs / bband_fs;

    if (isempty(offs))
        error('janus:rx:nosig', 'no signal detected');
    end
    
    if (verbose)
        figure(1);
        plot((0 : length(bband) - 1) / bband_fs, real(bband), 'b', ...
             [0 pset.chip_dur] + state.after, [real(bband(offs)) ...
             real(bband(offs + chip_nsample)) ], 'or');
        xlim([-1 2] * pset.chip_dur + state.after);
    end
    
    max_cfactor = 1540 / (1540 - max_speed);
    if (params.doppler_correction)
        [state.gamma, state.speed] = compute_doppler(bband(offs : offs + ...
            ceil(32 * chip_nsample * max_cfactor)).', pset.chip_dur, pset.chip_frq, ...
            freq_vec(chip_order), bband_fs, pset.cfreq, max_speed, 32);
    else
        state.gamma = 1;
        state.speed = NaN;
    end

    % Skip 32 chips.
    offs = offs + round(32 * bband_fs * pset.chip_dur / state.gamma);
 
    %% Decode packet.
    pkt_len = ceil(pkt_nchip * bband_fs * pset.chip_dur / state.gamma);
    %disp([offs pkt_len length(bband)])
    if (offs + pkt_len > length(bband))
        error('janus:rx:sigshort', 'signal too short to contain a valid packet');
    end
    state.pkt_idx = offs;
    
    signal = bband(offs : offs + pkt_len);
    state.process_up_to = (offs + pkt_len) / bband_fs;
    slots = slots(33 : end);
    
    [pkt_bytes, state.pkt_dec_bits, state.pkt_raw_bits pkt_bit_prob] = demod(pset, signal, bband_fs, slots, PKT_MIN_NBIT, state.gamma);
    %NEW CODE FOR IMPLEMENTATION OF NEW PROTOCOL ARCHITECTURE%
    %These new lines were inserted by Yannick Beaupre in association with Carleton University Feb 2023%
    %START%
    %_______________________________________________________________________%
    
    %Get counter from packet
    %------
    offs = offs + pkt_len + 1;

    ctr_nbits = 32;
    ctr_nchip = ALPHABET_SIZE * (ctr_nbits + CONV_ENC_MEM);
    ctr_len = ceil(ctr_nchip * bband_fs * pset.chip_dur / state.gamma);

    if (offs + ctr_len > length(bband))
        error('janus:rx:sigshort', 'signal too short to contain a valid counter');
    end
    state.ctr_idx = offs;
    

    signal = bband(offs : offs + ctr_len);
    state.process_up_to = (offs + pkt_len) / bband_fs;
    slots = hop_pattern(pset.prim_a, pset.prim_q, 32 + pkt_nchip + ctr_nchip);
    slots = slots(32 + pkt_nchip + 1 : end);

    [counterData, state.crg_dec_bits state.crg_raw_bits crg_bit_prob] ...
        = demod(pset, signal, bband_fs, slots, ctr_nbits, state.gamma);

    counterData = dec2bin(counterData);
    counterBin = '';

    for i = 1:32
        if(i == 24)
            counterBin = strcat(counterBin, counterData(31));
        elseif(i == 32)
            counterBin = strcat(counterBin, counterData(32));
        else
            counterBin = strcat(counterBin, counterData(mod(4*(i-1)+1, 31)));
        end
    end
    counter = bin2dec(counterBin);
    %------

    pkt_bits = dec2bin(pkt_bytes)-'0';

    %Export block 1 to for use with the TUBC32
    file = fopen("build/ciphertext.txt", "wt");
    for i = 1:32
        index = mod((i-1)*8+1, 63);
        fprintf(file, '%d', pkt_bits(index));
    end
    fprintf(file, '');
    fclose(file);

    %Generate Extended Key for block 1
    key = '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';
    epoch = '00000000000000000000000000000000';
    
    IV = dec2bin(2*(counter));
    IVUnpaddedLength = strlength(IV);
    
    for i = IVUnpaddedLength:31
        IV = strcat('0', IV);
    end
    
    %concatenation = epoch + key + IV;
    concatenation = [];
    index = 1;
    
    %Convert epoch to bytes
    for i = 0:3
        concatenation(index) = Byte.parseByte(string(toSignedInt(epoch(((i*8)+1):((i*8)+8)))));
        index = index + 1;
    end
    
    %Convert key to bytes
    for i = 0:31
        concatenation(index) = Byte.parseByte(string(toSignedInt(key(((i*8)+1):((i*8)+8)))));
        index = index + 1;
    end
    
    hashVariable = {'00000000','00000001','00000010','00000011','00000100', '00000101', '00000110'};
    
    %Convert IV to bytes
    for i = 0:3
        concatenation(index) = Byte.parseByte(string(toSignedInt(IV(((i*8)+1):((i*8)+8)))));
        index = index + 1;
    end
    
    extendedKeyBytes = [];
    
    %Create 7 hashes and concatenate them to create the extended key
    for i = 0:6
        %Create hash
        concatenation(41) = Byte.parseByte(hashVariable(i+1), 2);
        MD = MessageDigest.getInstance("SHA-512");
        hash = MD.digest(concatenation);
        for j = 1:64
            %Concatenate to form extended key
            extendedKeyBytes((i*64)+j) = hash(j);
        end
    end
    
    extendedKey = '';
    
    %Convert each byte to a string and concatenate them to prepare the key for
    %use with the TUBcipher
    for i = 1:448
        extendedKey = strcat(extendedKey, toString(extendedKeyBytes(i)));
    end

    %Export extended key to file for use with TUBC32
    file = fopen("build/extendedKey.txt", "wt");
    fprintf(file, extendedKey);
    fclose(file);

    %Decrypt block 1
    system("TUBC32_Decrypt.exe");

    %Load decrypted block 1
    file = fopen("build/plaintext.txt", "r");
    plaintext1 = fscanf(file, "%s");
    fclose(file);

    %Export block 2 for use with the TUBC32
    testString = "";
    file = fopen("build/ciphertext.txt", "wt");
    for i = 1:32
        index = mod((i-1)*8+5, 63);
        if index == 0
            index = 63;
        elseif index == 1
            index = 64;
        end
        fprintf(file, '%d', pkt_bits(index));
        testString = strcat(testString, int2str(pkt_bits(index)));
    end
    fprintf(file, '');
    fclose(file);

    %Generate Extended Key for block 2
    IV = dec2bin(2*(counter)+1);
    IVUnpaddedLength = strlength(IV);
    
    for i = IVUnpaddedLength:31
        IV = strcat('0', IV);
    end

    %Convert key to bytes
    for i = 0:31
        concatenation(index) = Byte.parseByte(string(toSignedInt(key(((i*8)+1):((i*8)+8)))));
        index = index + 1;
    end
    
    %concatenation = epoch + key + IV;
    concatenation = [];
    index = 1;
    
    %Convert epoch to bytes
    for i = 0:3
        concatenation(index) = Byte.parseByte(string(toSignedInt(epoch(((i*8)+1):((i*8)+8)))));
        index = index + 1;
    end
    
    hashVariable = {'00000000','00000001','00000010','00000011','00000100', '00000101', '00000110'};
    
    %Convert IV to bytes
    for i = 0:3
        concatenation(index) = Byte.parseByte(string(toSignedInt(IV(((i*8)+1):((i*8)+8)))));
        index = index + 1;
    end
    
    extendedKeyBytes = [];
    
    %Create 7 hashes and concatenate them to create the extended key
    for i = 0:6
        %Create hash
        concatenation(41) = Byte.parseByte(hashVariable(i+1), 2);
        MD = MessageDigest.getInstance("SHA-512");
        hash = MD.digest(concatenation);
        for j = 1:64
            %Concatenate to form extended key
            extendedKeyBytes((i*64)+j) = hash(j);
        end
    end
    
    extendedKey = '';
    
    %Convert each byte to a string and concatenate them to prepare the key for
    %use with the TUBcipher
    for i = 1:448
        extendedKey = strcat(extendedKey, toString(extendedKeyBytes(i)));
    end
    
    %Export extended key to file for use with TUBC32
    file = fopen("build/extendedKey.txt", "wt");
    fprintf(file, extendedKey);
    fclose(file);

    %Decrypt block 2
    system("TUBC32_Decrypt.exe"); 

    %Load decrypted block 2
    file = fopen("build/plaintext.txt", "r");
    plaintext2 = fscanf(file, "%s");
    fclose(file);

    %Form packet
    plaintext = strcat(plaintext1, plaintext2);
    for i = 1:8
        bitstring = extractAfter(plaintext, (i-1)*8);
        bitstring = extractBefore(bitstring, 9);
        pkt_bytes(i) = bin2dec(bitstring); 
    end
    %_______________________________________________________________________%
    %END%
    [pkt, err] = packet_unpack(pkt_bytes);
    if (err ~= 0)
        % continue decoding in case of invalid CRC
        disp ('janus:rx:invcrc invalid CRC')
        % error('janus:rx:invcrc', 'invalid CRC');        
    end

    if (~isfield(pkt, 'cargo_size') || pkt.cargo_size == 0)
        state.bit_prob = pkt_bit_prob;
        return
    end
    %disp([pkt_len pkt.cargo_size])
    
    offs = offs + pkt_len + 1;

    %% Decode optional cargo.
    crg_nbits = pkt.cargo_size * 8;
    crg_nchip = ALPHABET_SIZE * (crg_nbits + CONV_ENC_MEM);
    crg_len = ceil(crg_nchip * bband_fs * pset.chip_dur / state.gamma);

    %disp([offs crg_len length(bband)])
    if (offs + crg_len > length(bband))
        error('janus:rx:sigshort', 'signal too short to contain a valid cargo');
    end
    state.crg_idx = offs;
    

    signal = bband(offs : offs + crg_len);
    state.process_up_to = (offs + pkt_len) / bband_fs;
    slots = hop_pattern(pset.prim_a, pset.prim_q, 32 + pkt_nchip + crg_nchip);
    slots = slots(32 + pkt_nchip + 1 : end);

    [pkt.cargo, state.crg_dec_bits state.crg_raw_bits crg_bit_prob] ...
        = demod(pset, signal, bband_fs, slots, crg_nbits, state.gamma);
    
    try
        plugin = sprintf('plugin_%03d_%02d', pkt.class_id, pkt.app_type);
        eval(['[pkt.app_fields] = ' plugin '(''cargo_decode'', pkt.cargo, '...
              'pkt.cargo_size, pkt.app_fields);']);
    catch ME
        if (verbose)
            disp([plugin ': ' ME.message '.' ]);
        end
    end

    state.bit_prob = [pkt_bit_prob; crg_bit_prob];
end

%HELPER FUNCTIONS FOR NEW ARCHITECTURE
%These new lines were inserted by Yannick Beaupre in association with Carleton University Feb 2023%
function signedInt = toSignedInt(bitstring)
    signedInt = 0;
    value = 1;
    for i = 8:-1:1
        if char(extract(bitstring, i)) == '1'
            signedInt = signedInt + value;
        end
        value = value * 2;
    end
    if char(extract(bitstring, 1)) == '1'
        signedInt = signedInt - 256;
    end
end

function bitstring = toString(byte)
    if byte < 0
       bitstring = '1';
       byte = byte + 128;
    else
        bitstring = '0';
    end

    for i = 6:-1:0
        if (byte - (2^i)) < 0
            bitstring = strcat(bitstring, '0');
        else
            bitstring = strcat(bitstring, '1');
            byte = byte - (2^i);
        end
    end

end

