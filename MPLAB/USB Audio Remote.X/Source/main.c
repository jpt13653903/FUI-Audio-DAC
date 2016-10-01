#include "config.h"
#include "global.h"
//------------------------------------------------------------------------------

bool Active = false;
word Count  = 0;
//------------------------------------------------------------------------------

interrupt void OnInterrupt(){
 if(INTCONbits.T0IF){
  if(Active){
   Count++;
   if(Count > 1000) Active = false;

  }else{
   Active = true;
   Count  = 0;
  }
  LED = Active;

  NOP();
  NOP();

  Tx = !Tx;
  INTCONbits.T0IF = 0;
 }

 if(INTCONbits.RAIF){
  Active = true;
  Count  = 0;
  byte Temp = PORTA;
  INTCONbits.RAIF = 0;
 }

 if(INTCONbits.INTF){
  Active = true;
  Count  = 0;
  INTCONbits.INTF = 0;
 }
}
//------------------------------------------------------------------------------

void main(){
 OPTION_REGbits.nRAPU  = 1; // Disable weak pull-ups
 OPTION_REGbits.INTEDG = 0; // Interrupt on falling edge of INT pin
 OPTION_REGbits.T0CS   = 0; // Timer 0 uses internal clock
 OPTION_REGbits.PSA    = 0; // Prescaler assigned to Timer 0
 OPTION_REGbits.PS     = 0; // Timer 0 rate = 1:2 => 500 μs clock

 CMCONbits.CM = 7; // Switch off comparators

 ANSEL = 0; // Disable analogue functionality
 WPUA  = 0; // Disable weak pull-up on port A

 PORTC = 0;
 TRISA = 0xFF;
 TRISC = 0xC0;

 IOCA = 0x30; // Interrupt-on-change on A4 and A5

 INTCONbits.RAIE = 1; // Enable port A interrupt-on-change
 INTCONbits.INTE = 1; // Enable INT pin interrupt

 INTCONbits.T0IE = 1; // Enable interrupt on Timer 0
 INTCONbits.GIE  = 1; // Enable global interrupts

 while(1){
  if(!Active) SLEEP();
 }
}
//------------------------------------------------------------------------------
