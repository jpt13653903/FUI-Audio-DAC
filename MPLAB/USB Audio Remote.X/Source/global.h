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
