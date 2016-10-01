#ifndef global_h
#define global_h
//------------------------------------------------------------------------------

#define byte  unsigned char
#define word  unsigned short
#define dword unsigned long

#define bool  byte
#define true  1
#define false 0
//------------------------------------------------------------------------------

#define LED       PORTCbits.RC4
#define Tx        PORTCbits.RC5
#define Volume1   PORTAbits.RA4
#define Volume2   PORTAbits.RA5
#define Buttons  (PORTC & 0x0F)
#define Interrupt PORTAbits.RA2
//------------------------------------------------------------------------------

#endif
//------------------------------------------------------------------------------
