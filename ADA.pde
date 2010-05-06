#include <OneWire.h>
#include <LiquidCrystal.h>

OneWire ds(3);  // on pin 3
LiquidCrystal lcd(14, 15, 13, 12, 11, 10);

//assigning ports 
const int zero=4;
const int dimes=5;
const int pennies=6;
const int nickels=7;
const int quarters=8;
const int LEDpin=9;
const int timeout=5000;

//buffer for username
char user[25];


byte LEDstate=0;
unsigned long LEDtimer=0;

void setup(void) {
  // initialize inputs/outputs
  pinMode(zero,INPUT);
  pinMode(dimes,INPUT);
  pinMode(pennies,INPUT);
  pinMode(nickels,INPUT);
  pinMode(quarters,INPUT);
  pinMode(LEDpin,OUTPUT);
  
  //internal pullup resister
  //--pulldown could possibly do a pulldown resistor
  digitalWrite(zero,HIGH);
  digitalWrite(dimes,HIGH);
  digitalWrite(pennies,HIGH);
  digitalWrite(nickels,HIGH);
  digitalWrite(quarters,HIGH);
  digitalWrite(LEDpin,HIGH);
  
  //set up LCD for a 24x2 display
  lcd.begin(24, 2);
  // Print a message to the LCD.
  lcd.print("Welcome!");
  
  // start serial port
  Serial.begin(9600);
  
}

void loop(void) {
  byte i;
  byte present = 0;
  byte data[12];
  byte addr[8];
  byte maxCoin=0;
  byte nonZero=0;
  byte buff[6];
  int totalValue=0;
  int oldValue=0; 
  
  lcd.clear();
  lcd.home();
  lcd.print("Welcome! Touch Ibutton");
  lcd.setCursor(0,1);
  lcd.print("to continue!");
  delay(100);  
  unsigned long timer=0;
  
  if ( LEDtimer + 500 < millis()){
    LEDtimer = millis();
    LEDstate ^= 0x01;
    digitalWrite(LEDpin,LEDstate);
  }

  //return if there are no devices connected to the network
  if ( !ds.search(addr)) {
      ds.reset_search();
      return;
  }
  
  //the CRC is invalid ie: invalid iButton device
  if ( OneWire::crc8( addr, 7) != addr[7]) {
      return;
  }
 
  oldValue = Validate(addr,timeout, user);
  if(oldValue ==-1){
    return;
  }
 
  timer = millis();
  
  digitalWrite(LEDpin,LOW);

    lcd.clear();
    lcd.home();
    lcd.print("Welcome:");
    for (int i=0;i<16 && user[i]!='}';i++){
       lcd.print(user[i]);
    }
    lcd.setCursor(0,1);
    lcd.print( (oldValue+totalValue),DEC);
    lcd.print(" credits!");
  
  while(timer+10000>millis()){
     
    
    //checks if getting reading on way in or way back
    if(!digitalRead(dimes) && maxCoin==0 && digitalRead(zero)){
      maxCoin = 10;
      nonZero=true;
      timer=millis();
    }

    if(!digitalRead(pennies) && maxCoin==10){
      maxCoin = 1;
      nonZero=true;
      timer=millis();
    }

    if(!digitalRead(nickels) && maxCoin==1){
      maxCoin = 5;
      nonZero=true;
      timer=millis();
    }
    
    if(!digitalRead(quarters) && maxCoin==5){
      maxCoin = 25;
      nonZero=true;
      timer=millis();
    }
   
    if(!digitalRead(zero) && nonZero){
      //we're done recieving a coin;
      totalValue+=maxCoin;
      maxCoin = 0;
      nonZero=0;
      timer=millis();
      
      //update LCD
      lcd.setCursor(0,1);
      lcd.print( (oldValue+totalValue),DEC);
      lcd.print(" credits!");
      
      
    }
  }
  
  //print out iButton
  //totalValue=Validate(addr,timeout);
  Serial.print("W=");
  for( i = 0; i < 8; i++) {
    printByte(addr[i]);
    Serial.print(" ");
  }
  
  Serial.print(totalValue,DEC);
  Serial.print("\n");
}


int WaitForTimeout(int timeout){
  unsigned long timer = millis();
  while(!Serial.available() && timer + timeout > millis()){
    if ( LEDtimer + 50 < millis()){
      LEDtimer = millis();
      LEDstate ^= 0x01;
      digitalWrite(LEDpin,LEDstate);
    } 
  }
  return Serial.available();
}


int Validate(byte addr[8],int timeout, char* User){
  byte buff[6];
  int oldValue = -1;
  
  //update LCD
  lcd.clear();
  lcd.home();
  lcd.print("Validating ibutton:");
  lcd.setCursor(0,1);
  
  Serial.flush(); 
  Serial.print("R=");
  
  for( int i = 0; i < 8; i++) {
    lcd.print(addr[i],HEX);
    lcd.print(" ");
    printByte(addr[i]);
    Serial.print(" ");
  }
  
  //sending information to server and recieving
  while(oldValue<0){
    
    if(!WaitForTimeout(timeout)){
      
      return -1;
    }
    
    if((buff[0]=Serial.read())=='V'){
      
      if(!WaitForTimeout(timeout)){
         lcd.clear();
        lcd.home();
        lcd.print("Comm timeout!");
        delay(500);
        return-1;
      }
      if(Serial.read()==' '){
        for(int i=0;i<6;i++){
          if(!WaitForTimeout(timeout)){
            return -1;
          }
          buff[i]=Serial.read();
          if (buff[i]-'0'>9) return -1;
        }     
        oldValue=0;
        for(int i=0;i<6;i++){
          oldValue+=((unsigned int)(pow(10,(5-i))+.1))*(buff[i]-'0');
          Serial.print(" ");
        }
        for(int i=0;i<25;i++){
          if(!WaitForTimeout(timeout)){
            return oldValue;
          }
          User[i]=Serial.read();
          if (User[i]=='}'){
            i=25; 
          }
        }
        return oldValue;
      }
    }
    else if (buff[0] =='I'){
       lcd.clear();
      lcd.home();
      lcd.print("Invalid Ibutton!");
      delay(500);
      return -1;
    }
    
  }
  
  Serial.print("\n");
  
}

//creates the correct byte print output for server
void printByte(byte toPrint){
  byte temp;
  temp= (toPrint/16); //get first character... See More
  if (temp<10){
    
    Serial.write(temp+'0'); //first char is numeric
  }
  else{
    Serial.write(temp+'A'-10); //first char is alpha
  }
  temp=(toPrint%16); //get second character
  if (temp<10){
    Serial.write(temp+'0'); //second char is numeric
  }
  else{
    Serial.write(temp+'A'-10); //second char is alpha
  }
}
