#include "config.h"
#include "global.h"
//------------------------------------------------------------------------------

interrupt void OnInterrupt(){
 static word j = 0;
 j = (j+1) % 1953;

 if(j == 0) LED = !LED;

 INTCONbits.T0IF = 0;
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

 INTCONbits.T0IE = 1;
 INTCONbits.GIE  = 1;

 while(1); // Everything else is interrupt-driven...
}
//------------------------------------------------------------------------------
