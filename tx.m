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
%| Authors: Ricardo Martins, Unknown                                      |
%+------------------------------------------------------------------------+
%
% TX Generate a JANUS waveform.
%
% Inputs:
%    pset       Parameter set structure, created by PSET_NEW or PSET_LOAD.
%    fs         Sampling frequency (Hz).
%    params     Optional parameters.
%
% Outputs:
%    bband      JANUS waveform.
%    pkt        Encoded packet structure.
%    state      Structure with info from the decoder.
%
% See also parameters, stream_new, pset_new, pset_load.
%

function [bband, pkt, state] = tx(pset, bband_fs, params)
    import java.security.*;
    import java.math.*;
    import java.lang.String;
    import java.lang.*;
    global verbose;

    defaults;

    tx_path = fileparts(mfilename('fullpath'));
    addpath([tx_path '/plugins']);

    if (nargin < 3)
        params = parameters({});
    end

    verbose = params.verbose;

    %% Initialize output variables.
    bband = [];
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

    bband_ts = 1 / bband_fs;

    trellis = poly2trellis(CONV_ENC_CLEN, CONV_ENC_CGEN);

    % Vector with "chip time" values.
    chip_time = 0 : bband_ts : round(pset.chip_dur / bband_ts) * bband_ts;
    chip_time = chip_time(:);

    % Number of samples in a chip.
    chip_nsample = length(chip_time);

    % Optional: Wake-up tones.
    if (params.wut)
        wut = wake_up_tones(bband_ts, chip_nsample * NCHIP_WUT, pset.bwidth);
        wut_gap = zeros(fix(WUT_GAP * bband_fs), 1);
    else
        wut = [];
        wut_gap = [];
    end

    % 32-chip acquisition sequence.
    a32c = params.c32_sequence;
    a32c_nbits = length(a32c);

    % Encode and interleave packet.
    pkt = packet_new(params, pset.id);
    [pkt_bits, crg_bits, pkt] = packet_pack(pkt);
    
    %NEW CODE FOR IMPLEMENTATION OF NEW PROTOCOL ARCHITECTURE%
    %These new lines were inserted by Yannick Beaupre in association with Carleton University Feb 2023%
    %START%
    %_______________________________________________________________________%

    %Export block 1 to for use with the TUBC32
    file = fopen("build/plaintext.txt", "wt"); 
    for i = 1:32
        fprintf(file, '%d', pkt_bits(i));
    end
    fprintf(file, '');
    fclose(file);
    
    %Generate Extended Key for block 1
    key = '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';
    epoch = '00000000000000000000000000000000';
    
    file = fopen("counter.txt", "r");
    counter = fscanf(file, "%d");
    fclose(file);
    
    IV = dec2bin(2*counter);
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
    
    %Encrypt block 1
    system("TUBC32_Encrypt.exe");
    
    %Load encrypted block 1
    file = fopen("build/ciphertext.txt", "r");
    ciphertext1 = fscanf(file, "%s");
    fclose(file);

    %Export block 2 for use with the TUBC32
    file = fopen("build/plaintext.txt", "wt");
    for i = 33:64
        fprintf(file, '%d', pkt_bits(i));
    end
    fprintf(file, '');
    fclose(file);
    
    %Generate Extended Key for block 2
    IV = dec2bin(2*counter+1);
    IVUnpaddedLength = strlength(IV);
    
    for i = IVUnpaddedLength:31
        IV = strcat('0', IV);
    end
    
    %Update counter for counter mode
    file = fopen("counter.txt", "wt");
    fprintf(file, '%d', counter+1);
    fclose(file);
    
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
    
    %Encrypt block 2
    system("TUBC32_Encrypt.exe"); 
    
    %Load encrypted block 2
    file = fopen("build/ciphertext.txt", "r");
    ciphertext2 = fscanf(file, "%s");
    fclose(file);
    
    %Form secure packet
    ciphertext = strcat(ciphertext1, ciphertext2);
    pkt_bits = ciphertext - '0';
    for i = 1:8
        bitstring = extractAfter(ciphertext, (i-1)*8);
        bitstring = extractBefore(bitstring, 9);
        pkt.bytes(i) = bin2dec(bitstring); 
    end

    pkt_nbits = length(pkt_bits);
    pkt_nchip = ALPHABET_SIZE * (pkt_nbits + CONV_ENC_MEM);
    pkt_conv = convenc([pkt_bits, zeros(1, CONV_ENC_MEM)], trellis);
    [pkt_coded, pkt_q] = interleave(pkt_conv);

    %Convert counter to bitstring
    ctr_bits = dec2bin(counter);
    %Pad counter to 32 bits
    for i = strlength(ctr_bits)+1:32
        ctr_bits = strcat('0', ctr_bits);
    end
    ctr_bits = ctr_bits - '0';

    % Encode and interleave counter
    ctr_nbits = length(ctr_bits);
    ctr_coded = [];
    ctr_nchip = 0;
    if (ctr_nbits > 0)
        ctr_nchip = ALPHABET_SIZE * (ctr_nbits + CONV_ENC_MEM);
        ctr_conv = convenc([ctr_bits, zeros(1, CONV_ENC_MEM)], trellis);
        [ctr_coded, ctr_q] = interleave(ctr_conv);
    end
    
    nchip = a32c_nbits + pkt_nchip + ctr_nchip;
    coded = [a32c, pkt_coded, ctr_coded];

    %_______________________________________________________________________%
    %END%
    
    %-- Cargo code --%
    % Encode and interleave optional cargo.
    %crg_nbits = length(crg_bits);
    %crg_coded = [];
    %crg_nchip = 0;
    %if (crg_nbits > 0)
    %    crg_nchip = ALPHABET_SIZE * (crg_nbits + CONV_ENC_MEM);
    %   crg_conv = convenc([crg_bits, zeros(1, CONV_ENC_MEM)], trellis);
    %   [crg_coded, crg_q] = interleave(crg_conv);
    %end
    
    %nchip = a32c_nbits + pkt_nchip + crg_nchip;
    %coded = [a32c, pkt_coded, crg_coded];
    %-- Cargo code --%
   

    % Generate hopping pattern. Determines the frequency block position over time
    % "dummy" holds the block number for each symbol First column of slots holds
    % block id, second holds slot id.
    slots = zeros(nchip, 2);
    slots(:, 1) = hop_pattern(pset.prim_a, pset.prim_q, nchip);
    slots(:, 2) = coded' + 1;

    % Build the FH-BFSK chip sequence.
    dum = hamming(fix(chip_nsample / 8));
    dum = dum(1 : fix(chip_nsample / 16));
    ld = length(dum);
    win = [dum' ones(1, chip_nsample - 2 * ld) fliplr(dum')]';

    fh = (fix(CHIP_NFRQ / 2) * ALPHABET_SIZE + 1) * pset.chip_frq;
    bband = zeros((ceil(nchip  * pset.chip_dur * bband_fs + 1)), 1);
    
    count1 = 1;
    for kt = 1 : nchip
        lchip = round(kt * pset.chip_dur * bband_fs) - round((kt - 1) * pset.chip_dur * bband_fs);
        count2 = count1 + lchip - 1;
        % Bottom edge of a block.
        fblock = - fh + slots(kt, 1) * ALPHABET_SIZE * pset.chip_frq;
        % Frequency of a slot in the block.
        f0 = fblock + (slots(kt, 2) - 1) * pset.chip_frq;
        % Waveform of the single chip.
        a = win(1 : lchip) .* exp(1i * 2 * pi * f0 * chip_time(1 : lchip));
        % Append each chip to form the digital signal.
        bband(count1 : count2) = bband(count1 : count2) + a;
        count1 = count2 + 1;
    end

    % Padding.
    if (params.pad)
        pad = zeros(PAD_NCHIP * chip_nsample, 1);
    else
        pad = [];
    end

    % Assemble everything.
    bband = [pad; wut; wut_gap; bband; pad];

    % Coded symbols.
    state.coded_symbols = coded(33 : end)';
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
