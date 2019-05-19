;*********************************************************************************************
;*                                  Dehumidifier Project                                     *
;* ----------------------------------------------------------------------------------------- *
;*                                       Main Board                                          *
;*===========================================================================================*
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
;* The main controller of the Dehumidifier. The System takes measurements of the environ-    *
;* mental parameters and controls the high power actuators enable the compressor, fan and    *
;* ionizer of a Juro Pro Oxygen16L Dehumidifier                                              *
;*===========================================================================================*
			.cdecls C,LIST,"msp430.h"			;Include device header file
			.include "Board.h43"				;Board connections
			.include "Definitions.h43"			;General definitions of the project
			.include "Keyboard/Keyboard.h43"	;Keyboard Library


;*********************************************************************************************
; Global Definitions
;-------------------------------------------
			.def	StartMe						;Entry point should be global


;*********************************************************************************************
; Constants
;-------------------------------------------
			.sect ".const"


;*********************************************************************************************
; Functions
;----------------------------------------
			.text								;Assemble into program memory.
			.retain								;Overide ELF conditional linking and retain
												; current section.
			.retainrefs							;and retain any sections that have references
												; to current section.


;----------------------------------------
; StartMe
; This is the entry point of the program
StartMe:
			MOV.W	#StckStrt,SP				;Stack pointer at the top of RAM
StopWDT:	MOV.W	#WDTPW|WDTHOLD,&WDTCTL		;Stop watchdog timer


;-------------------------------------------
; Stack Pointer definition
;===========================================
			.global	StckStrt
			.sect	.stack
StckStrt:


;-------------------------------------------
; Interrupt Vectors
;===========================================
			.sect	".reset"					;MSP430 RESET Vector
			.short	StartMe

