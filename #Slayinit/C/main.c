#include <stdio.h> //TODO
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <makestuff.h>
#include <libfpgalink.h>
#include <libbuffer.h>
#include <liberror.h>
#include <libdump.h>
// #include <argtable2.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <stdbool.h>
#include <stdint.h> 
#include <unistd.h>
#ifdef WIN32
#include <Windows.h>
#else
#include <sys/time.h>
#endif 


bool sigIsRaised(void);
void sigRegisterHandler(void);

typedef enum {
    FLP_SUCCESS,
    FLP_LIBERR,
    FLP_BAD_HEX,
    FLP_CHAN_RANGE,
    FLP_CONDUIT_RANGE,
    FLP_ILL_CHAR,
    FLP_UNTERM_STRING,
    FLP_NO_MEMORY,
    FLP_EMPTY_STRING,
    FLP_ODD_DIGITS,
    FLP_CANNOT_LOAD,
    FLP_CANNOT_SAVE,
    FLP_ARGS
} ReturnCode;

void decrypt (uint8_t* ciphertext, uint32_t* k) { 
    uint32_t v0 = ciphertext[3]<<24 | ciphertext[2]<<16 | ciphertext[1]<<8 | ciphertext[0];  
    uint32_t v1 = ciphertext[7]<<24 | ciphertext[6]<<16 | ciphertext[5]<<8 | ciphertext[4];
    uint32_t sum=0xC6EF3720, i;  /* set up */
    uint32_t delta=0x9e3779b9;                     /* a key schedule constant */
    uint32_t k0=k[0], k1=k[1], k2=k[2], k3=k[3];   /* cache key */
    for (i=0; i<32; i++) {                         /* basic cycle start */
        v1 -= ((v0<<4) + k2) ^ (v0 + sum) ^ ((v0>>5) + k3);
        v0 -= ((v1<<4) + k0) ^ (v1 + sum) ^ ((v1>>5) + k1);
        sum -= delta;
    }                     
    for(int i=0; i<8; i++){  // Not sure if this'll work
        if(i<4){
            ciphertext[i]=(v0 >> 8*i);
        }
        else{
            ciphertext[i]=(v1 >> 8*(i-4));
        }
    }
}         

void encrypt (uint8_t* plaintext, uint32_t* k) {
    uint32_t v0 = plaintext[3]<<24 | plaintext[2]<<16 | plaintext[1]<<8 | plaintext[0];
    uint32_t v1 = plaintext[7]<<24 | plaintext[6]<<16 | plaintext[5]<<8 | plaintext[4];
    uint32_t sum=0, i;           /* set up */
    uint32_t delta=0x9e3779b9;                     /* a key schedule constant */
    uint32_t k0=k[0], k1=k[1], k2=k[2], k3=k[3];   /* cache key */
    for (i=0; i < 32; i++) {                       /* basic cycle start */
        sum += delta;
        v0 += ((v1<<4) + k0) ^ (v1 + sum) ^ ((v1>>5) + k1);
        v1 += ((v0<<4) + k2) ^ (v0 + sum) ^ ((v0>>5) + k3);
    }                                              /* end cycle */

    for(int i=0; i<8; i++){  
        if(i<4){
            plaintext[i]=(v0 >> 8*i);
        }
        else{
            plaintext[i]=(v1 >> 8*(i-4));
        }
    }
}  

const char* getfield(char* line, int num){
    const char* tok;
    // char * temp;
   // char *d = malloc (strlen (line) + 1);   // Space for length plus nul
    //if (d == NULL) return NULL;          // No memory
    //strcpy (d,line);  
    // memcpy(temp,line,strlen(line));
    // int length = strlen(line);
     char* dst= strdup(line);
    // while(*dst ++ = *line ++);
    for (tok = strtok(dst, ",");
            tok && *tok;
            tok = strtok(NULL, ",\n"))
    {
        if (!--num){
            // free(temp);
            return tok;
        } 
    }
    // free(temp);
    return NULL;
}

int check_if_valid(int usrId, int pin, int cashRequired, char** store, int rows, bool *superUser, bool *sufficientFunds){ // Check validity using the csv file
    int i=1;
    bool usrFound=false;
    int usrIndex;
    // printf("%d\n",rows); //REM
    while(i<rows){
        int j;
        sscanf(getfield(store[i], 1),"%d",&j); 

        if(j == usrId){
            usrFound =true;
            usrIndex=i;
        }
        else{
            
        }
        i++;
    }
    if(usrFound){
        int j;
        sscanf(getfield(store[usrIndex], 2),"%d",&j); 

        if( j == pin){
            sscanf(getfield(store[usrIndex], 3),"%d",&j);
            // printf("%d\n", j); //REM
            if(j == 1){
                *superUser=true;
            }
            else{
                *superUser=false;
                sscanf(getfield(store[usrIndex], 4),"%d",&j);
                // printf("%s,%d\n", "superuser=false",j); //REM
                if(j >= cashRequired){
                    *sufficientFunds=true;
                }
                else{
                    *sufficientFunds=false;
                }
            }
            return usrIndex;
        }
        else{
            return -2; // User Found Incorrect Pin
        }
    }
    else{
        return -1; // User Not Found
    }
}       
void changeAmt(int usrIndex, int cashRequiredInt, char** store, int rows){
    FILE* newStream = fopen("SampleBackEndDatabase.csv", "w");
    int j;
    sscanf(getfield(store[usrIndex], 4),"%d",&j);  
    j=j-cashRequiredInt;
    for (int i = 0; i < rows; i++){
        if(i==usrIndex){
            if(i!=rows-1){
                fprintf(newStream, "%s,%s,%s,%d\n", getfield(store[usrIndex], 1), getfield(store[usrIndex], 2), getfield(store[usrIndex], 3), j);
            }
            else{
                fprintf(newStream, "%s,%s,%s,%d", getfield(store[usrIndex], 1), getfield(store[usrIndex], 2), getfield(store[usrIndex], 3), j);
            }
        }
        else{
            fprintf(newStream, "%s", store[i]);
        }
    }
    fclose(newStream);
}

void putCashValue(int usrIndex, int cashRequiredInt, char** store, int rows){
    FILE* newStream = fopen("SampleBackEndDatabase.csv", "w");
    int j;
    j=cashRequiredInt;
    for (int i = 0; i < rows; i++){
        if(i==usrIndex){
            if(i!=rows-1){
                printf("done\n");
                printf("%d\n",usrIndex);

                fprintf(newStream, "%s,%s,%s,%d\n", getfield(store[usrIndex], 1), getfield(store[usrIndex], 2), getfield(store[usrIndex], 3), j);
            }
            else{
                printf("dafgsddone\n");
                fprintf(newStream, "%s,%s,%s,%d", getfield(store[usrIndex], 1), getfield(store[usrIndex], 2), getfield(store[usrIndex], 3), j);
            }
        }
        else{
            fprintf(newStream, "%s", store[i]);
        }
    }
    fclose(newStream);
}


int power(int a, int b){ // return type!
    int ans=1;
    for(int i=0; i<b; i++){
        ans=ans*a;
    }
    return ans;
}

void toInteger(int* binaryArray, uint8_t* integer){
    int answer=0; 
    for(int i=0; i<8; i++){
        answer=answer+binaryArray[i]*power(2, i);
    }
    *integer=answer;
} 

void toBinary8(uint8_t integer, int* binaryArray){
    for(int i=0; i<8; i++){
        binaryArray[i]=0;
    }
    for(int i=7; i>=0; i--){
        if(integer >= power(2, i)){
            binaryArray[i]=1;
            integer = integer-power(2, i);
        }   
    }
    
}

void findHash(uint8_t* pin, int bank_id){
    // Hash the pin to check
    int binaryArray1[8], binaryArray2[8];
    for(int i=0; i<8; i++){
        binaryArray1[i]=0;
        binaryArray2[i]=0;
     }
    toBinary8(pin[0], binaryArray1);
    toBinary8(pin[1], binaryArray2);

    int FbinaryArray1[8], FbinaryArray2[8]; 
    for(int i=0; i<8; i++){
        FbinaryArray1[i]=0;
        FbinaryArray2[i]=0;
    }

    for(int i=0; i<16; i++){
        int newPos;
        newPos=i+bank_id;
        newPos=newPos%16;
        if(i<8){
            if(newPos<8){
                FbinaryArray2[newPos]=binaryArray2[i];
            }
            else{
                FbinaryArray1[newPos-8]=binaryArray2[i];
            }
        }
        else{
            if(newPos<8){
                FbinaryArray2[newPos]=binaryArray1[i-8];
            }
            else{
                FbinaryArray1[newPos-8]=binaryArray1[i-8];
            }
        }
    }
    toInteger(FbinaryArray1, &pin[0]);
    toInteger(FbinaryArray2, &pin[1]);
} 

int main() {
    int bank_id;
    printf("Please give the bank id");
    gets( bank_id );

    ReturnCode retVal = FLP_SUCCESS;
    struct FLContext *handle = NULL;
    FLStatus fStatus;
    const char *error = NULL;
    char vp[] = "1d50:602b:0002";
    char ivp[] = "1443:0007";
    const char *lin = NULL;
    uint8 conduit = 0x01;

    
    fStatus = flInitialise(0, &error);
    CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);

    

    printf("Attempting to open connection to FPGALink device %s...\n", vp);
    // printf("fsdfs\n");

    fStatus = flOpen(vp, &handle, NULL);
    // CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);

    if ( fStatus ) {
        int count = 60;
        uint8 flag;
        
        
        printf("Loading firmware into %s...\n", ivp);
        fStatus = flLoadStandardFirmware(ivp, vp, &error);
        CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
        
        printf("Awaiting renumeration");
        flSleep(1000);
        do {
            printf(".");
            fflush(stdout);
            fStatus = flIsDeviceAvailable(vp, &flag, &error);
            CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
            flSleep(250);
            count--;
        } while ( !flag && count );
        printf("\n");
        if ( !flag ) {
            fprintf(stderr, "FPGALink device did not renumerate properly as %s\n", vp);
            FAIL(FLP_LIBERR, cleanup);
        }
        printf("Attempting to open connection to FPGLink device %s again...\n", vp);
        fStatus = flOpen(vp, &handle, &error);
        CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
    }

    printf(
        "Connected to FPGALink device %s (firmwareID: 0x%04X, firmwareVersion: 0x%08X)\n",
        vp, flGetFirmwareID(handle), flGetFirmwareVersion(handle)
    );

    int temp1 =0;
    int flag=0;
    while(true){
    
        // printf("%s","New Loop\n"); //REM
        uint8_t* buff;
        uint8_t buffn;
        uint8_t usrData[8];
        buff = &buffn;
            // printf("hello\n"); //REM
        if(temp1 == 0){
            // printf("hello\n"); //REM
            uint8 isRunning;  // Setting up the FPGA, Checking if it is ready
            fStatus = flSelectConduit(handle, conduit, &error);
            CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
            // printf("hello33\n");
            fStatus = flIsFPGARunning(handle, &isRunning, &error);
            CHECK_STATUS(fStatus, FLP_LIBERR, cleanup);
            if ( isRunning ) {
                // printf("hello11\n");
                FLStatus status = flReadChannel(handle,(uint8) 0, 1, buff, &error);
                // printf("hello11332\n");
                CHECK_STATUS(status, FLP_LIBERR, cleanup);
                // printf("hello11332\n");
            } else {
                // printf("hello23\n");
                fprintf(stderr, "The FPGALink device at %s is not ready to talk - did you forget --xsvf?\n", vp);
                FAIL(FLP_ARGS, cleanup);
            }
            
            // printf("hello\n"); //REM
            printf("%d\n",buffn); //REM
            if(buffn == 0x01 || buffn == 0x02||buffn==0x05){
                temp1=1;
                if(buffn == 0x02){
                    flag=1;

                }
                else if(buffn==0x01){
                    flag=0;
                }
                else 
                {
                	flag = 2;
                }
            }
        }
        else if(temp1 == 1){
            FLStatus status = flReadChannel(handle,(uint8) 0, 1, buff, &error);
            CHECK_STATUS(status, FLP_LIBERR, cleanup);
            printf("%d\n",buffn); //REM

            if(buffn == 0x01 || buffn == 0x02||buffn==0x05){
                
                if(buffn == 0x02 && flag==1){
                	temp1=2;
                    flag=1;
                }
                else if(buffn==0x01 && flag==0)
                {
                	flag=0;
                	temp1=2;
                }
                else if(buffn==0x05&&flag==2)
                {
                	temp1=2;
                }
                else{
                	temp1=0;
                    flag=0;
                }
            }
            else{
                temp1=0;
            }
        }
        else if(temp1 == 2){
            FLStatus status = flReadChannel(handle,(uint8) 0, 1, buff, &error);
            CHECK_STATUS(status, FLP_LIBERR, cleanup);
            printf("%d\n",buffn); //REM

            if(buffn == 0x01 || buffn == 0x02||buffn==0x05){
                temp1=3;
			if(buffn == 0x02 && flag==1){
                	temp1=3;
                    flag=1;
                }
                else if(buffn==0x01 && flag==0)
                {
                	flag=0;
                	temp1=3;
                }
                else if(buffn==0x05 && flag==2)
                {
                	temp1=4;	
                	flag=0;
                }
                else{
                	temp1=0;
                    flag=0;
                }
            }
            else{
                temp1=0;
            }
        }
        else if(temp1==4) 
        {
            printf("entered loop");
            uint8_t a[4];
            a[0]=0x01;  // 2000
            a[1]=0x06;
            a[2]=0x09;
            a[3]=0x03;
            uint8_t* tempBuff;
            uint8_t tempBuffn;
             tempBuff = &tempBuffn;
             for(int j=1;j<5;j++)
             {
                // printf("entered loop");
			 	tempBuffn = a[j-1];

			 	FLStatus status = flWriteChannel(handle,(uint8) j, 1, tempBuff, &error);
			 	CHECK_STATUS(status, FLP_LIBERR, cleanup);

			 }
            tempBuffn =0x04;
            temp1=0;
            flag=0;


		 }
        else if(temp1 == 3){
            // printf("%s\n","Reading chan 1-8"); //REM
            for(int i=1; i<9; i++){
                sleep(0.25);
                FLStatus status = flReadChannel(handle,(uint8) i, 1, &usrData[i-1], &error);
                status = flReadChannel(handle,(uint8) i, 1, &usrData[i-1], &error);
                status = flReadChannel(handle,(uint8) i, 1, &usrData[i-1], &error);
                status = flReadChannel(handle,(uint8) i, 1, &usrData[i-1], &error);
               
                CHECK_STATUS(status, FLP_LIBERR, cleanup);
                // printf("%s, %d, %d\n","channel value",i, usrData[i-1]); //REM
            }
            uint8_t temp_buff;
            FLStatus status = flReadChannel(handle,(uint8) 9, 1, &temp_buff, &error);
            

            uint8_t usrDataDec[8];
            for(int i=0; i<8; i++){
                usrDataDec[i]=usrData[i];
            }
            uint32_t key[4]; //Key used in TEA
            //x"ff0f7457 43fd99f7 75f8c48f 2927c18c"
            key[0]=0x2927c18c;
            key[1]=0x75f8c48f;
            key[2]=0x43fd99f7;
            key[3]=0xff0f7457;
            decrypt(usrDataDec, key);
            
            uint8_t usrId[2], pin[2], cashRequired[4];
            int usrIdInt, pinInt, cashRequiredInt;

            usrId[0]=usrDataDec[0]; usrId[1]=usrDataDec[1];
            pin[0]=usrDataDec[2]; pin[1]=usrDataDec[3];
            cashRequired[0]=usrDataDec[4]; cashRequired[1]=usrDataDec[5]; cashRequired[2]=usrDataDec[6]; cashRequired[3]=usrDataDec[7];
            
            findHash(pin, bank_id);  

            usrIdInt = usrId[0]*power(2,8)+usrId[1];
            pinInt = pin[0]*power(2,8)+pin[1];

            cashRequiredInt = (cashRequired[0]*power(2,24)) + (cashRequired[1]*power(2,16)) + (cashRequired[2]*power(2,8)) + (cashRequired[3]);
            
            printf("%s, %d, %d, %d\n", "usr details",usrIdInt, pinInt, cashRequiredInt); //REM
            FILE* stream = fopen("SampleBackEndDatabase.csv", "r");
            char* store[65535];
            char line[1024];
            int rows=0;
            printf("%s\n","csv opened"); //REM
            if(stream == NULL){
                printf("%s\n","file NULL"); //REM
            }
            printf("%s\n","csv opened"); //REM
            while (fgets(line, 1024, stream)){
                store[rows] = strdup(line);
                rows=rows+1;
            }
            fclose(stream);

            printf("%d",temp_buff);
            printf("%s\n","csv read!"); //REM
            printf("%s\n","csv read!"); //REM
            bool superUser=false;
            bool sufficientFunds=false;
            printf("%s\n", store[1]);
            int myCheckStatus = check_if_valid(usrIdInt, pinInt, cashRequiredInt, store, rows, &superUser, &sufficientFunds);
            printf("%s, %d\n","mycheckStatus",myCheckStatus); //REM
            if(temp_buff==0x01)
            {
                uint8_t caches[4];
                for(int j=10;j<14;j++)
                {
                    uint8_t TempBuff;
                    FLStatus status = flReadChannel(handle,(uint8) j, 1, &TempBuff, &error);
                    caches[j-10]=TempBuff;
                    printf("%d\n",TempBuff);

                }
                int total=0;
                int multi = 1;
                int multiplier = power(2,8);
                for(int i=3;i>-1;i--)
                {   
                    total = total + caches[i]*multi;
                    multi =  multi*multiplier;

                }
                printf("%d\n",total);
                if(myCheckStatus>=0)
                    putCashValue(myCheckStatus,total,store,rows);
 
            }
            stream = fopen("SampleBackEndDatabase.csv", "r");
            // char* store[65535];
            // char line[1024];
            rows=0;
            printf("%s\n","csv opened"); //REM
            if(stream == NULL){
                printf("%s\n","file NULL"); //REM
            }
            printf("%s\n","csv opened"); //REM
            while (fgets(line, 1024, stream)){
                store[rows] = strdup(line);
                rows=rows+1;
            }
             superUser=false;
             sufficientFunds=false;
            printf("%s\n", store[1]);
            myCheckStatus = check_if_valid(usrIdInt, pinInt, cashRequiredInt, store, rows, &superUser, &sufficientFunds);



            if(myCheckStatus == -1){ // usr not found

                uint8_t* tempBuff;
                uint8_t tempBuffn;
                tempBuff = &tempBuffn;
                tempBuffn =0x04;
                FLStatus status = flWriteChannel(handle,(uint8) 9, 1, tempBuff, &error);
                printf("channel 9,-1");
                printf("%d",tempBuff);
                CHECK_STATUS(status, FLP_LIBERR, cleanup); 
                tempBuffn =0x00;
                for(int i=1; i<9; i++){
                    FLStatus tempStatus = flWriteChannel(handle,(uint8) i+9, 1, tempBuff, &error);
                    CHECK_STATUS(tempStatus, FLP_LIBERR, cleanup);
                }
                // printf("%s\n", "usr not found, putting 4 in chan9 and 0 everywhere else"); //REM
            }
            else if(myCheckStatus == -2){ // incorrect pin
                uint8_t* tempBuff;
                uint8_t tempBuffn;
                tempBuff = &tempBuffn;
                tempBuffn =0x04;
                FLStatus status = flWriteChannel(handle, (uint8) 9, 1, tempBuff, &error);
                printf("channel 9,-2");
                printf("%d",tempBuff);
                tempBuffn =0x00;
                for(int i=1; i<9; i++){
                    FLStatus tempStatus = flWriteChannel(handle,(uint8) i+9, 1, tempBuff, &error);
                    CHECK_STATUS(tempStatus, FLP_LIBERR, cleanup);
                }
                CHECK_STATUS(status, FLP_LIBERR, cleanup);
                // printf("%s\n", "pin not found, putting 4 in chan9, putting 4 in chan9 and 0 everywhere else"); //REM
            }
            else{ //user and pin found
                printf("%s\n", "Valid user found");
                if(superUser){ //Does not matter if flag was 0 or 1
                    printf("%s\n", "User has admin privileges");
                    uint8_t* tempBuff;
                    uint8_t tempBuffn;
                    tempBuff = &tempBuffn;
                    tempBuffn =0x03;
                    FLStatus status = flWriteChannel(handle,(uint8) 9, 1, tempBuff, &error);
                    printf("channel 9,other");
                    printf("%d \n",*tempBuff);
                    CHECK_STATUS(status, FLP_LIBERR, cleanup);
                    uint8_t toSend[8];
                    for(int i=0; i<4; i++){
                        toSend[i]=0x00;
                    }
                    for(int i=4; i<8; i++){
                        toSend[i]=cashRequired[i-4];
                    }
                    uint32_t key[4]; //Key used in TEA
                    //x"ff0f7457 43fd99f7 75f8c48f 2927c18c"
                    key[0]=0x2927c18c;
                    key[1]=0x75f8c48f;
                    key[2]=0x43fd99f7;
                    key[3]=0xff0f7457;
                    encrypt(toSend, key);

                    for(int i=1; i<9; i++){
                        FLStatus tempStatus = flWriteChannel(handle,(uint8) (i+9), toSend[i-1], tempBuff, &error);
                        CHECK_STATUS(tempStatus, FLP_LIBERR, cleanup);
                    }
                }
                else{
                	
                        printf("here\n");
                        printf("%s\n","Vader funds found"); //REM

                    if(sufficientFunds){
                        printf("%s\n","Valid funds found"); //REM
                        uint8_t* tempBuff;
                        uint8_t tempBuffn;
                        tempBuff = &tempBuffn;
                        tempBuffn =0x01;
                        FLStatus status = flWriteChannel(handle,(uint8) 9, 1, tempBuff, &error);
                        printf("%s\n","channel 9,suff fund");
                        printf("%d\n",tempBuffn);
                        CHECK_STATUS(status, FLP_LIBERR, cleanup);
                        uint8_t toSend[8];
                        for(int i=0; i<4; i++){
                            toSend[i]=0x00;
                        }
                        for(int i=4; i<8; i++){
                            toSend[i]=cashRequired[i-4];
                        }
                        uint32_t key[4]; //Key used in TEA
                    //x"ff0f7457 43fd99f7 75f8c48f 2927c18c"
                        key[0]=0x2927c18c;
                        key[1]=0x75f8c48f;
                        key[2]=0x43fd99f7;
                        key[3]=0xff0f7457;
                        encrypt(toSend, key);

                        for(int i=1; i<9; i++){
                            FLStatus tempStatus = flWriteChannel(handle,(uint8) (i+9), toSend[i-1], tempBuff, &error);
                            CHECK_STATUS(tempStatus, FLP_LIBERR, cleanup);
                        }
                        if(flag==0){
                            changeAmt(myCheckStatus, cashRequiredInt, store, rows); //Changing users account info
                            int j;
                            sscanf(getfield(store[myCheckStatus], 4),"%d",&j);
                            j=j-cashRequiredInt;
                            // printf("%s, %d\n",'userFunds::', j);
                            uint32_t perse=  (uint32_t)j;
                            uint8_t kio[4];
                            for(int i=3; i>=0; i--){
                                kio[i]=perse;
                                perse = perse>>8;
                            }
                            
                            for(int i=18;i<22;i++)  
                            {
                               printf("here3243\n");
                               printf("%d\n",kio[i-18]);
                               FLStatus status = flWriteChannel(handle,(uint8) i,1 , &kio[i-18], &error);
                            }
                        }
                        else{

                            int j;
                            sscanf(getfield(store[myCheckStatus], 4),"%d",&j);
                            
                            // printf("%s, %d\n",'userFunds::', j);
                            uint32_t perse=  (uint32_t)j;
                            uint8_t kio[4];
                            for(int i=3; i>=0; i--){
                                kio[i]=perse;
                                perse = perse>>8;
                            }
                            
                            for(int i=18;i<22;i++)  
                            {
                               printf("here3243\n");
                               printf("%d\n",kio[i-18]);
                               FLStatus status = flWriteChannel(handle,(uint8) i,1 , &kio[i-18], &error);
                            }

                        }
                    }
                    else{
                        //Insufficint Funds
                        // printf("INValid funds found"); //REM

                        int j;

                            sscanf(getfield(store[myCheckStatus], 4),"%d",&j);
                            // printf("%s, %d\n",'userFunds::', j);
                            uint32_t perse=  (uint32_t)j;
                            uint8_t kio[4];
                            for(int i=3; i>=0; i--){
                                kio[i]=perse;
                                perse = perse>>8;
                            }
                            

                        uint8_t* tempBuff;
                        uint8_t tempBuffn;
                        tempBuff = &tempBuffn;
                        tempBuffn =0x02;
                        FLStatus status = flWriteChannel(handle,(uint8) 9, 1, tempBuff, &error);
                        printf("channel 9,insuff fund\n");
                        // printf("%d\n",*tempBuff);
                        CHECK_STATUS(status, FLP_LIBERR, cleanup);
                        tempBuffn=0x00;
                        for(int i=1; i<9; i++){
                            FLStatus tempStatus = flWriteChannel(handle, (uint8) i+9, 1, tempBuff, &error);
                            CHECK_STATUS(tempStatus, FLP_LIBERR, cleanup);
                        }
                        for(int i=18;i<22;i++)  
                        {
                        printf("here3243\n");
                           printf("%d\n",kio[i-18]); 
                           FLStatus status = flWriteChannel(handle,(uint8) i,1 , &kio[i-18], &error);
                        }
                    } 
                }
            }
            temp1=0;
            flag=0;
        }
        sleep(1);
    }

    
cleanup:
    free((void*)lin);
    flClose(handle);
    if ( error ) {
        fprintf(stderr, "%s\n", error);
        flFreeError(error);
    }
    return retVal;
}
