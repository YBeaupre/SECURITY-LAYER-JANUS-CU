#include <stdio.h>
#include <string.h>
#pragma warning(disable:4996)
#include "TUBC32.h"

char* XOR(char bitString[], char key[]) {
	/*
	* bitString: 32-bit block
	* key: 32-bit key
	* Output: bitString_i XOR key_i (for every bit in position i)
	*/

	char result[32];
	int leftBit;
	int rightBit;


	for (int i = 0; i < 32; i++) {
		leftBit = bitString[i] - '0';
		rightBit = key[i] - '0';
		result[i] = (leftBit ^ rightBit) + '0';
	}

	//Without this for loop, the cipher does not work properly.
	for (int i = 0; i < 32; i++) {
	}

	return result;
}

char* keyedPerm(char bitString[], char key[]) {
	/*
	* bitString: 32-bit block
	* key: 24-bit key
	* Output: key based permutation of 32-bit block
	*/

	char result[32];
	char c0;
	char c1;
	char c2;
	char c3;
	char a0;
	char a1;
	char a2;

	for (int i = 0; i < 8; i++) {
		c0 = bitString[4 * i];
		c1 = bitString[(4 * i) + 1];
		c2 = bitString[(4 * i) + 2];
		c3 = bitString[(4 * i) + 3];
		a0 = key[3 * i];
		a1 = key[(3 * i) + 1];
		a2 = key[(3 * i) + 2];

		if ((a0 == '0') && (a1 == '0') && (a2 == '0')) {
			result[4 * i] = c0;
			result[(4 * i) + 1] = c1;
			result[(4 * i) + 2] = c2;
			result[(4 * i) + 3] = c3;
		}
		else if ((a0 == '0') && (a1 == '0') && (a2 == '1')) {
			result[4 * i] = c1;
			result[(4 * i) + 1] = c0;
			result[(4 * i) + 2] = c3;
			result[(4 * i) + 3] = c2;
		}
		else if ((a0 == '0') && (a1 == '1') && (a2 == '0')) {
			result[4 * i] = c2;
			result[(4 * i) + 1] = c3;
			result[(4 * i) + 2] = c0;
			result[(4 * i) + 3] = c1;
		}
		else if ((a0 == '0') && (a1 == '1') && (a2 == '1')) {
			result[4 * i] = c1;
			result[(4 * i) + 1] = c0;
			result[(4 * i) + 2] = c2;
			result[(4 * i) + 3] = c3;
		}
		else if ((a0 == '1') && (a1 == '0') && (a2 == '0')) {
			result[4 * i] = c3;
			result[(4 * i) + 1] = c2;
			result[(4 * i) + 2] = c1;
			result[(4 * i) + 3] = c0;
		}
		else if ((a0 == '1') && (a1 == '0') && (a2 == '1')) {
			result[4 * i] = c2;
			result[(4 * i) + 1] = c1;
			result[(4 * i) + 2] = c0;
			result[(4 * i) + 3] = c3;
		}
		else if ((a0 == '1') && (a1 == '1') && (a2 == '0')) {
			result[4 * i] = c3;
			result[(4 * i) + 1] = c1;
			result[(4 * i) + 2] = c2;
			result[(4 * i) + 3] = c0;
		}
		else {
			result[4 * i] = c0;
			result[(4 * i) + 1] = c2;
			result[(4 * i) + 2] = c1;
			result[(4 * i) + 3] = c3;
		}
		
	}
	return result;
}

char* roundEnc(char bitString[], char bigKey[], char smallKey[]) {
	/*
	* bitString: 32-bit block to be encrypted
	* bigKey: 32-bit key
	* smallKey: 24-bit key
	* Output: a single round of the permutation-substitution network applied to the 32-bit block for encryption
	*/

	//XOR
	char* xorBits = XOR(bitString, bigKey);

	//Fixed permutation
	char resultPerm[32];
	for (int i = 0; i < 32; i++) {
		resultPerm[(3 * i) % 32] = xorBits[i];
	}

	//Keyed permutation
	char *currentResult = keyedPerm(resultPerm, smallKey);

	//Fixed substitution
	char result[32];
	int W = 0;

	for (int i = 0; i < 8; i++) {
		W = 0;

		if (currentResult[4 * i] == '1') {
			W += 1000;
		}

		if (currentResult[(4 * i) + 1] == '1') {
			W += 100;
		}

		if (currentResult[(4 * i) + 2] == '1') {
			W += 10;
		}

		if (currentResult[(4 * i) + 3] == '1') {
			W += 1;
		}

		if (W == 0) {
			//0 -> 0
			result[4 * i] = '0';
			result[(4 * i) + 1] = '0';
			result[(4 * i) + 2] = '0';
			result[(4 * i) + 3] = '0';
		}
		else if (W == 1) {
			//1 -> 10
			result[4 * i] = '1';
			result[(4 * i) + 1] = '0';
			result[(4 * i) + 2] = '1';
			result[(4 * i) + 3] = '0';
		}
		else if (W == 10) {
			//2 -> 7
			result[4 * i] = '0';
			result[(4 * i) + 1] = '1';
			result[(4 * i) + 2] = '1';
			result[(4 * i) + 3] = '1';
		}
		else if (W == 11) {
			//3 -> 14
			result[4 * i] = '1';
			result[(4 * i) + 1] = '1';
			result[(4 * i) + 2] = '1';
			result[(4 * i) + 3] = '0';
		}
		else if (W == 100) {
			//4 -> 5
			result[4 * i] = '0';
			result[(4 * i) + 1] = '1';
			result[(4 * i) + 2] = '0';
			result[(4 * i) + 3] = '1';
		}
		else if (W == 101) {
			//5 -> 2
			result[4 * i] = '0';
			result[(4 * i) + 1] = '0';
			result[(4 * i) + 2] = '1';
			result[(4 * i) + 3] = '0';
		}
		else if (W == 110) {
			//6 -> 12
			result[4 * i] = '1';
			result[(4 * i) + 1] = '1';
			result[(4 * i) + 2] = '0';
			result[(4 * i) + 3] = '0';
		}
		else if (W == 111) {
			//7 -> 15
			result[4 * i] = '1';
			result[(4 * i) + 1] = '1';
			result[(4 * i) + 2] = '1';
			result[(4 * i) + 3] = '1';
		}
		else if (W == 1000) {
			//8 -> 6
			result[4 * i] = '0';
			result[(4 * i) + 1] = '1';
			result[(4 * i) + 2] = '1';
			result[(4 * i) + 3] = '0';
		}
		else if (W == 1001) {
			//9 -> 11
			result[4 * i] = '1';
			result[(4 * i) + 1] = '0';
			result[(4 * i) + 2] = '1';
			result[(4 * i) + 3] = '1';
		}
		else if (W == 1010) {
			//10 -> 3
			result[4 * i] = '0';
			result[(4 * i) + 1] = '0';
			result[(4 * i) + 2] = '1';
			result[(4 * i) + 3] = '1';
		}
		else if (W == 1011) {
			//11 -> 8
			result[4 * i] = '1';
			result[(4 * i) + 1] = '0';
			result[(4 * i) + 2] = '0';
			result[(4 * i) + 3] = '0';
		}
		else if (W == 1100) {
			//12 -> 13
			result[4 * i] = '1';
			result[(4 * i) + 1] = '1';
			result[(4 * i) + 2] = '0';
			result[(4 * i) + 3] = '1';
		}
		else if (W == 1101) {
			//13 -> 1
			result[4 * i] = '0';
			result[(4 * i) + 1] = '0';
			result[(4 * i) + 2] = '0';
			result[(4 * i) + 3] = '1';
		}
		else if (W == 1110) {
			//14 -> 4
			result[4 * i] = '0';
			result[(4 * i) + 1] = '1';
			result[(4 * i) + 2] = '0';
			result[(4 * i) + 3] = '0';
		}
		else{
		//15 -> 9
		result[4 * i] = '1';
		result[(4 * i) + 1] = '0';
		result[(4 * i) + 2] = '0';
		result[(4 * i) + 3] = '1';
		}

	}

	return result;

}

char* roundDec(char bitString[], char bigKey[], char smallKey[]) {
	/*
	* bitString: 32-bit block to be decrypted
	* bigKey: 32-bit key
	* smallKey: 24-bit key
	* Output: a single round of the permutation-substitution network applied to the 32-bit block for decryption
	*/

	//Fixed substitution
	char resultSub[32];
	int W = 0;

	for (int i = 0; i < 8; i++) {
		W = 0;

		if (bitString[4 * i] == '1') {
			W += 1000;
		}

		if (bitString[(4 * i) + 1] == '1') {
			W += 100;
		}

		if (bitString[(4 * i) + 2] == '1') {
			W += 10;
		}

		if (bitString[(4 * i) + 3] == '1') {
			W += 1;
		}

		if (W == 0) {
			//0 -> 0
			resultSub[4 * i] = '0';
			resultSub[(4 * i) + 1] = '0';
			resultSub[(4 * i) + 2] = '0';
			resultSub[(4 * i) + 3] = '0';
		}
		else if (W == 1) {
			//1 -> 13
			resultSub[4 * i] = '1';
			resultSub[(4 * i) + 1] = '1';
			resultSub[(4 * i) + 2] = '0';
			resultSub[(4 * i) + 3] = '1';
		}
		else if (W == 10) {
			//2 -> 5
			resultSub[4 * i] = '0';
			resultSub[(4 * i) + 1] = '1';
			resultSub[(4 * i) + 2] = '0';
			resultSub[(4 * i) + 3] = '1';
		}
		else if (W == 11) {
			//3 -> 10
			resultSub[4 * i] = '1';
			resultSub[(4 * i) + 1] = '0';
			resultSub[(4 * i) + 2] = '1';
			resultSub[(4 * i) + 3] = '0';
		}
		else if (W == 100) {
			//4 -> 14
			resultSub[4 * i] = '1';
			resultSub[(4 * i) + 1] = '1';
			resultSub[(4 * i) + 2] = '1';
			resultSub[(4 * i) + 3] = '0';
		}
		else if (W == 101) {
			//5 -> 4
			resultSub[4 * i] = '0';
			resultSub[(4 * i) + 1] = '1';
			resultSub[(4 * i) + 2] = '0';
			resultSub[(4 * i) + 3] = '0';
		}
		else if (W == 110) {
			//6 -> 8
			resultSub[4 * i] = '1';
			resultSub[(4 * i) + 1] = '0';
			resultSub[(4 * i) + 2] = '0';
			resultSub[(4 * i) + 3] = '0';
		}
		else if (W == 111) {
			//7 -> 2
			resultSub[4 * i] = '0';
			resultSub[(4 * i) + 1] = '0';
			resultSub[(4 * i) + 2] = '1';
			resultSub[(4 * i) + 3] = '0';
		}
		else if (W == 1000) {
			//8 -> 11
			resultSub[4 * i] = '1';
			resultSub[(4 * i) + 1] = '0';
			resultSub[(4 * i) + 2] = '1';
			resultSub[(4 * i) + 3] = '1';
		}
		else if (W == 1001) {
			//9 -> 15
			resultSub[4 * i] = '1';
			resultSub[(4 * i) + 1] = '1';
			resultSub[(4 * i) + 2] = '1';
			resultSub[(4 * i) + 3] = '1';
		}
		else if (W == 1010) {
			//10 -> 1
			resultSub[4 * i] = '0';
			resultSub[(4 * i) + 1] = '0';
			resultSub[(4 * i) + 2] = '0';
			resultSub[(4 * i) + 3] = '1';
		}
		else if (W == 1011) {
			//11 -> 9
			resultSub[4 * i] = '1';
			resultSub[(4 * i) + 1] = '0';
			resultSub[(4 * i) + 2] = '0';
			resultSub[(4 * i) + 3] = '1';
		}
		else if (W == 1100) {
			//12 -> 6
			resultSub[4 * i] = '0';
			resultSub[(4 * i) + 1] = '1';
			resultSub[(4 * i) + 2] = '1';
			resultSub[(4 * i) + 3] = '0';
		}
		else if (W == 1101) {
			//13 -> 12
			resultSub[4 * i] = '1';
			resultSub[(4 * i) + 1] = '1';
			resultSub[(4 * i) + 2] = '0';
			resultSub[(4 * i) + 3] = '0';
		}
		else if (W == 1110) {
			//14 -> 3
			resultSub[4 * i] = '0';
			resultSub[(4 * i) + 1] = '0';
			resultSub[(4 * i) + 2] = '1';
			resultSub[(4 * i) + 3] = '1';
		}
		else {
			//15 -> 7
			resultSub[4 * i] = '0';
			resultSub[(4 * i) + 1] = '1';
			resultSub[(4 * i) + 2] = '1';
			resultSub[(4 * i) + 3] = '1';
		}
	}

	//Keyed permutation
	char *resultPerm = keyedPerm(resultSub, smallKey);

	//Fixed permutation
	char currentResult[32];
	for (int i = 0; i < 32; i++) {
		currentResult[(11 * i) % 32] = resultPerm[i];
	}

	//XOR
	char *result = XOR(currentResult, bigKey);

	return result;
}

char* encrypt(char plaintext[], char key[]) {
	/*
	* plaintext: 32-bit block to be encrypted
	* key: 3584-bit key
	* Output: encrypted 32-bit block
	*/

	char bitString[32];
	strncpy(bitString, plaintext, 32);

	//Complete 56 rounds of the substitution-permutation network
	for (int i = 0; i < 56;i++) {

		//Build subkeys
		char bigKey[32];
		char smallKey[24];
		
		for (int j = 0; j < 32; j++) {
			bigKey[j] = key[(56 * i)+j];
		}

		for (int j = 0; j < 24; j++) {
			smallKey[j] = key[(56 * i) + 32 + j];
		}

		char newBitString[32];
		strcpy(newBitString,roundEnc(bitString, bigKey, smallKey));

		for (int i = 0; i < 32; i++) {
			bitString[i] = newBitString[i];
		}
	}
	return bitString;
}

char* decrypt(char ciphertext[], char key[]) {
	/*
	* ciphertext: 32-bit block to be decrypted
	* key: 3584-bit key
	* Output: decrypted 32-bit block
	*/

	char bitString[32];
	strncpy(bitString, ciphertext, 32);

	//Complete 56 rounds of the substitution-permutation network
	for (int i = 55; i > -1; i--) {

		//Build subkeys
		char bigKey[32];
		char smallKey[24];

		for (int j = 0; j < 32; j++) {
			bigKey[j] = key[(56 * i) + j];
		}

		for (int j = 0; j < 24; j++) {
			smallKey[j] = key[(56 * i) + 32 + j];
		}

		char newBitString[32];
		strcpy(newBitString, roundDec(bitString, bigKey, smallKey));

		for (int i = 0; i < 32; i++) {
			bitString[i] = newBitString[i];
		}
	}
	return bitString;
}

int main() {
	//Read plaintext from file
	char plaintext[32];
	FILE* filePlaintext = fopen("build/plaintext.txt", "r");
	for (int i = 0; i < 32; i++) {
		plaintext[i] = fgetc(filePlaintext);
	}
	fclose(filePlaintext);

	//Read extended key from file
	char extendedKey[3584];
	FILE* fileKey = fopen("build/extendedKey.txt", "r");
	for (int i = 0; i < 3584; i++) {
		extendedKey[i] = fgetc(fileKey);
	}
	fclose(fileKey);

	//Encrypt plaintext
	char ciphertext[32];
	strcpy(ciphertext, encrypt(plaintext, extendedKey));

	//Output to file
	FILE* fileCiphertext = fopen("build/ciphertext.txt", "w");
	for (int i = 0; i < 32; i++) {
		fprintf(fileCiphertext, "%c", ciphertext[i]);
	}

	return 0;
}