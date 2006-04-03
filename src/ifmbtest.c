/*
 * Simple test program for the IF metabase
 */

#include <stdio.h>

#include "ifmetabase.h"

int main() {
	int x;
	
	IFID id;
	IFID lastId = NULL;
	const char* testIds[] = {
		"ZCODE-01-010101",
		"ZCODE-01-010101-abcd",
		"ZCODE-01-------",
		"UUID://1974A053-7DB0-4103-93A1-767C1382C0B7//",
		"GLULX-01-010101-abcd1010",
		"GLULX-abcd1010-ffffaaaa",
		"TADS-01234567890123456789012345678901",
		"01234567890123456789012345678901",
		NULL
	};

	/* ID tests */
	for (x=0; testIds[x] != NULL; x++) {
		printf("%s ........ ", testIds[x]);
		
		id = IFMB_IdFromString(testIds[x]);
		if (id == NULL) {
			printf("Failed to create\n");
			continue;
		}
		
		if (IFMB_CompareIds(id, id) != 0) {
			printf("Isn't equal to self\n");
			continue;
		}
		
		if (lastId != NULL && IFMB_CompareIds(id, lastId) == 0) {
			printf("Is equal to last ID\n");
			continue;
		}
		
		if (lastId != NULL) IFMB_FreeId(lastId);
		
		printf("OK\n");
		lastId = id;
	}
	
	if (lastId != NULL) IFMB_FreeId(lastId);
	
	/* Metabase tests */
	IFMetabase mb = IFMB_Create();
	IFStory stories[64];
	
	printf("\nCreating stories...\n\n");
	
	for (x=0; testIds[x] != NULL; x++) {
		IFID id = IFMB_IdFromString(testIds[x]);

		printf("%s ........ ", testIds[x]);
		
		stories[x] = IFMB_GetStoryWithId(mb, id);
		IFStory secondStory = IFMB_GetStoryWithId(mb, id);
		
		if (stories[x] != secondStory) {
			printf("Created story twice\n");
			continue;
		}
		
		printf("OK\n");
		
		IFMB_FreeId(id);
	}
	
	printf("\nReading stories...\n\n");
	
	for (x=0; testIds[x] != NULL; x++) {
		IFID id = IFMB_IdFromString(testIds[x]);
		
		printf("%s ........ ", testIds[x]);
		
		IFStory secondStory = IFMB_GetStoryWithId(mb, id);
		
		if (secondStory == NULL) {
			printf("Not found\n");
			continue;
		}
		
		if (IFMB_CompareIds(id, IFMB_IdForStory(secondStory)) != 0) {
			printf("IDs do not match\n");
			continue;
		}
		
		if (stories[x] != secondStory) {
			printf("Created story twice\n");
			continue;
		}
		
		printf("OK\n");
		
		IFMB_FreeId(id);
	}
	
	return 0;
}
