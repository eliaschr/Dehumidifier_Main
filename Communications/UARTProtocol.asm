;*********************************************************************************************
;* UART Protocol Library                                                                     *
;*-------------------------------------------------------------------------------------------*
;* UARTProtocol.asm                                                                          *
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
;* Library of procedures for communicating to the Front Panel board through UART-RS232 bus.  *
;* The two systems, Main board and Front Panel, exchange data for the indications (from main *
;* to Front Panel) and for the keystrokes (from Front Panel to the Main board). In the       *
;* indications data there can be data to a graphical TFT screen for graphical presentation.  *
;* As for the data that come from the Front Panel, the keystrokes can be also touch codes    *
;* from a resistive touchscreen.                                                             *
;* The same protocol should be used at both the Main and the Front Panel boards.             *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"UART Protocol Library"
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
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "UARTProtocol.h43"		;Local definitions
			.include "ProtoAutoDefs.h43"	;Auto definitions according to settings in
											; UARTProtocol.h43


;----------------------------------------
; Definitions
;========================================


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	InPacket, PACKETSIZE	;Incoming packet construction buffer
			.bss	OutPacket, PACKETSIZE   ;Outgoing packet construction buffer
			

;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text
;Interrupt Service Routines must be global
			.global	ISRName


;----------------------------------------
; FunctionName
; Function Description
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
FunctionName:
			RET
			

;----------------------------------------
; Interrupt Service Routines
;========================================
;----------------------------------------
; ISRName
; ISR Description
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
ISRName:
			RETI


;----------------------------------------
; Interrupt Vectors
;========================================
;			.sect	ISR_Vector_Segment
;			.short	ISRName
