#ifndef TUBC32
#define TUBC32

char* roundEnc(char bitString[], char bigKey[], char smallKey[]);

char* roundDec(char bitString[], char bigKey[], char smallKey[]);

char* encrypt(char plaintext[], char key[]);

char* decrypt(char ciphertext[], char key[]);

#endif