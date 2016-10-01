//==============================================================================
// Copyright (C) John-Philip Taylor
// jpt13653903@gmail.com
//
// This file is part of FUI Audio DAC
//
// This file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>
//==============================================================================

#include "config.h"
#include "global.h"
//------------------------------------------------------------------------------

bool Active      = false;
byte ActiveCount = 0;
byte Volume      = 0;
//------------------------------------------------------------------------------

void MakeActive(){
 Active      = true;
 ActiveCount = 0;

 Interrupt        = 1;
 TRISC            = 0xCF;
 TRISAbits.TRISA2 = 0;

 INTCONbits.INTE = 0;
 INTCONbits.T0IE = 1;
}
//------------------------------------------------------------------------------

void OnVolumeChange(){
 static byte Prev = 0;
 
 byte Next = (Volume2 << 1) | Volume1;

 switch((Prev << 4) | Next){
  case 0x01:
  case 0x13:
  case 0x32:
  case 0x20:
   Volume++;
   break;

  case 0x02:
  case 0x10:
  case 0x31:
  case 0x23:
   Volume--;
   break;

  default:
   break;
 }

 Prev = Next;
}
//------------------------------------------------------------------------------

byte Parity(word Data){
 byte Result;

 Result = (Data   & 0xFF) ^ (Data   >> 8);
 Result = (Result & 0x0F) ^ (Result >> 4);
 Result = (Result & 0x03) ^ (Result >> 2);
 Result = (Result & 0x01) ^ (Result >> 1);
 
 // Has to be odd parity to ensure that the final edge is falling
 return (~Result) & 1;
}
//------------------------------------------------------------------------------

void OnTimer(){
 typedef enum STATE_TAG{
  Idle,
  SendEdge,
  SendData
 } STATE;
 
 static STATE State = Idle;
 static byte  Count = 0;
 static word  Data;

 switch(State){
  case Idle:
   Count++;
   if(Count == 3){
    Data = Buttons;
    Data = (Data << 8) | Volume;
    Data = (Data << 4) | Parity(Data);

    Count = 0;
    State = SendEdge;
   }
   break;

  case SendEdge:
   Tx = !Tx;

   if(Count == 16){
    ActiveCount++;
    if(ActiveCount > 25) Active = false;

    Count = 0;
    State = Idle;

   }else{
    State = SendData;
   }
   break;

  case SendData:
   if(Data & 0x8000) Tx = !Tx;
   Data = Data << 1;

   Count++;
   State = SendEdge;

   break;

  default:
   break;
 }
}
//------------------------------------------------------------------------------

interrupt void OnInterrupt(){
 // Interrupt-on-change, port A
 if(INTCONbits.RAIF){
  MakeActive    ();
  INTCONbits.RAIF = 0;
 }

 // Interrupt on falling edge of INT pin
 if(INTCONbits.INTF){
  MakeActive();
  INTCONbits.INTF = 0;
 }

 // Interrupt on Timer 0 overflow
 if(INTCONbits.T0IF){
  if(Buttons) ActiveCount = 0;

  OnVolumeChange(); // Uses slow-sampling to de-bounce: sample every 500 μs

  OnTimer();

  INTCONbits.T0IE = Active;
  LED             = Active;

  INTCONbits.T0IF = 0;
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

 IOCA            = 0x30; // Interrupt-on-change on A4 and A5
 INTCONbits.RAIE = 1;    // Enable port A interrupt-on-change

 while(1){
  if(!Active){
   INTCONbits.GIE = 0;
    PORTC = 0;
    TRISA = 0xFF;
    TRISC = 0xC0;
    INTCONbits.INTF = 0;
    INTCONbits.INTE = 1;
   INTCONbits.GIE = 1;
   SLEEP();
  }
 }
}
//------------------------------------------------------------------------------
