;*********************************************************************************************
;* CRC16 Library                                                                             *
;*-------------------------------------------------------------------------------------------*
;* CRC16.asm                                                                                 *
;* Author: eliaschr                                                                          *
;* Copyright (c) 2019, Elias Chrysocheris                                                    *
;*                                                                                           *
;* This program is free software: you can redistribute it and/or modify                      *
;* it under the terms of the GNU General Public License as published by                      *
;* the Free Software Foundation, either version 3 of the License, or                         *
;* (at your option) any later version.                                                       *
;*                                                                                           *
;* This program is distributed in the hope that it will be useful,                           *
;* but WITHOUT ANY WARRANTY; without even the implied warranty of                            *
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                             *
;* GNU General Public License for more details.                                              *
;*                                                                                           *
;* You should have received a copy of the GNU General Public License                         *
;* along with this program.  If not, see <https://www.gnu.org/licenses/>.                    *
;*-------------------------------------------------------------------------------------------*
;* Library of procedures for calculating CRC16 checksums, using the hardware module. CRC16   *
;* is very important for checking communication integrity, especially in a electromagnetic   *
;* noisy environment.                                                                        *
;* The library supports both normal and reversed bit order                                   *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"CRC16 Library"
			.width	94
			.tab	4

;*===========================================================================================*
;* Names And Values:                                                                         *
;* ------------------                                                                        *
;*                                                                                           *
;*===========================================================================================*
;* Variables:                                                                                *
;* -----------                                                                               *
;*                                                                                           *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* --------------------------                                                                *
;* CRC16Init        : Initializes the CRC16 hardware module                                  *
;* CRC16Add         : Adds a byte into the CRC16 calculation                                 *
;* CRC16AddRB       : Adds a byte into the CRC16 calculation in reverse bit order            *
;* CRC16AddResult   : Adds a byte in CRC16 sum and gets the resulting CRC16                  *
;* CRC16AddResultRB : Adds a byte in CRC16 sum and gets the resulting CRC16. The input byte  *
;*                     and the result is in reverse bit order                                *
;* CRC16AddList     : Adds a whole list of bytes into the CRC16 sun and returns the current  *
;*                     CRC16 checksum                                                        *
;* CRC16AddListRB   : Adds a whole list of bytes into the CRC16 sun and returns the current  *
;*                     CRC16 checksum. Values and result are in bit reversed order           *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "CRC16.h43"			;Local definitions
			.include "CRC16AutoDefs.h43"	;Auto definitions according to settings in
											; CRC16.h43


;----------------------------------------
; Definitions
;========================================


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------


;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text
;Interrupt Service Routines must be global


;----------------------------------------
; CRC16Init
; Initializes the CRC16 hardware module by writing the initial seed
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : CRC16Seed
; OTHER FUNCS   : None
CRC16Init:	MOV		#CRC16Seed,&CRCINIRES			;Initialize the seed of the CRC engine
			RET


;----------------------------------------
; CRC16Add
; Adds a byte value into the CRC16 calculated checksum
; INPUT         : R4 contains the byte to be added
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16Add:	MOV.B	R4,&CRCDI_L						;Input a byte of data in CRC16 module
			RET


;----------------------------------------
; CRC16AddW
; Adds a word value into the CRC16 calculated checksum
; INPUT         : R4 contains the word to be added
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16AddW:	MOV		R4,&CRCDI						;Input a word of data in CRC16 module
			RET


;----------------------------------------
; CRC16AddResult
; Adds a byte value into the CRC16 calculated checksum and returns its result
; INPUT         : R4 contains the byte to be added
; OUTPUT        : R4 contains the currently calculated CRC16 checksum
; REGS USED     : R4
; REGS AFFECTED : R4
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16AddResult:
			MOV.B	R4,&CRCDI_L						;Input a byte of data in CRC16 module
			MOV		&CRCINIRES,R4					;Get the CRC16 sum
			RET


;----------------------------------------
; CRC16AddWResult
; Adds a word value into the CRC16 calculated checksum and returns its result
; INPUT         : R4 contains the word to be added
; OUTPUT        : R4 contains the currently calculated CRC16 checksum
; REGS USED     : R4
; REGS AFFECTED : R4
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16AddWResult:
			MOV		R4,&CRCDI						;Input a word of data in CRC16 module
			MOV		&CRCINIRES,R4					;Get the CRC16 sum
			RET


;----------------------------------------
; CRC16Result
; Returns the currently calculates CRC16 checksum
; INPUT         : None
; OUTPUT        : R4 contains the currently calculated CRC16 checksum
; REGS USED     : R4
; REGS AFFECTED : R4
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16Result:
			MOV		&CRCINIRES,R4					;Get the CRC16 checksum
			RET


;----------------------------------------
; CRC16ResultRB
; Returns the currently calculates CRC16 checksum in reverse bit order
; INPUT         : None
; OUTPUT        : R4 contains the currently calculated CRC16 checksum
; REGS USED     : R4
; REGS AFFECTED : R4
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16ResultRB:
			MOV		&CRCRESR,R4					;Get the CRC16 checksum
			RET


;----------------------------------------
; CRC16AddList
; Adds a list of values into the CRC16 calculated checksum. The list is stored in a buffer in
; memory.
; INPUT         : R5 points to the first word to be added (start of data buffer)
;                 R6 contains the number of bytes to be included in the ckecksum
; OUTPUT        : R4 contains the currently calculated CRC16 checksum
; REGS USED     : R4, R5, R6
; REGS AFFECTED : R4, R5, R6
;                 R5 points just after the input stream of data included in CRC16 checksum
;                 R6 is zeroed
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16AddList:
			MOV.B	@R5+,&CRCDI_L					;Input a word of data in CRC16 module
			DEC		R6
			JNZ		CRC16AddList					;Repeat for all R6 bytes
			MOV		&CRCINIRES,R4					;Get the CRC16 sum
			RET


;----------------------------------------
; CRC16AddRB
; Adds a byte of value into the CRC16 calculated checksum. The value is added in reversed bit
; order
; INPUT         : R4 contains the byte to be added
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16AddRB:	MOV.B	R4,&CRCDIRB_L					;Input a byte of data in CRC16 module
			RET


;----------------------------------------
; CRC16AddWRB
; Adds a word value into the CRC16 calculated checksum. The value is added in reversed bit
; order
; INPUT         : R4 contains the word to be added
; OUTPUT        : None
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16AddWRB:MOV		R4,&CRCDIRB						;Input a word of data in CRC16 module
			RET


;----------------------------------------
; CRC16AddResultRB
; Adds a byte value into the CRC16 calculated checksum. The value is added in reversed bit
; order
; INPUT         : R4 contains the byte to be added
; OUTPUT        : R4 contains the currently calculated CRC16 checksum
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16AddResultRB:
			MOV.B	R4,&CRCDIRB_L					;Input a word of data in CRC16 module
			MOV		&CRCRESR,R4					;Get the CRC16 sum
			RET


;----------------------------------------
; CRC16AddWResultRB
; Adds a word value into the CRC16 calculated checksum and returns the current result. The
; value is added in reversed bit order
; INPUT         : R4 contains the word to be added
; OUTPUT        : R4 contains the currently calculated CRC16 checksum
; REGS USED     : R4
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16AddWResultRB:
			MOV		R4,&CRCDIRB						;Input a word of data in CRC16 module
			MOV		&CRCRESR,R4					;Get the CRC16 sum
			RET


;----------------------------------------
; CRC16AddList
; Adds a list of values into the CRC16 calculated checksum. The list is stored in a buffer in
; memory. The values are added in reversed bit order
; INPUT         : R5 points to the first word to be added (start of data buffer)
;                 R6 contains the number of bytes to be included in the ckecksum
; OUTPUT        : R4 contains the currently calculated CRC16 checksum in reverse bit order
; REGS USED     : R4, R5, R6
; REGS AFFECTED : R4, R5, R6
;                 R5 points just after the input stream of data included in CRC16 checksum
;                 R6 is zeroed
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
CRC16AddListRB:
			MOV.B	@R5+,&CRCDIRB_L					;Input a word of data in CRC16 module
			DEC		R6
			JNZ		CRC16AddListRB					;Repeat for all R6 bytes
			MOV		&CRCRESR,R4					;Get the CRC16 sum
			RET


;----------------------------------------
; Interrupt Service Routines
;========================================


;----------------------------------------
; Interrupt Vectors
;========================================
