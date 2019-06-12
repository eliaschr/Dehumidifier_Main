;*********************************************************************************************
;* NTC Library                                                                               *
;*-------------------------------------------------------------------------------------------*
;* NTC.asm                                                                                   *
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
;* Library of procedures for making temperature measurements through a NTC.                  *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"NTC Library"
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
			.include "Resources/ADC.h43"	;Use the ADC library
			.include "NTC.h43"				;Local definitions
			.include "NTCAutoDefs.h43"		;Auto definitions according to settings in
											; NTC.h43


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
; NTCPInit
; Initializes the NTC I/O port pins
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 4 = Call + Stack from called function
; VARS USED     : DEF_NTCMCTL, NTC_ACHANNEL, NTC_ENABLE, NTCA_PMASK, NTCA_SEL0, NTCA_SEL1,
;                 NTCP_DIR, NTCP_DOUT
; OTHER FUNCS   : ADCSetChannel
NTCPInit:	
			BIC.B	#NTC_ENABLE,&NTCP_DOUT			;Disable the NTC
			BIS.B	#NTC_ENABLE,&NTCP_DIR			;Enable pin is output
			BIS.B	#NTCA_PMASK,&NTCA_SEL0			;The input pin is an Analog Input to ADC
			BIS.B	#NTCA_PMASK,&NTCA_SEL1
			MOV		#NTC_ACHANNEL,R10				;Going to setup the NTC Analog Channel
			MOV		#DEF_NTCMCTL,R11				;The value to be used as MCTLx
			CALL	#ADCSetChannel					;Setup the channel
			RET
			

;----------------------------------------
; NTCTrigger
; Initializes the NTC I/O port pins
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 2 = 1x Call
; VARS USED     : NTC_ACHANNEL
; OTHER FUNCS   : ADCStartSingle
NTCTrigger:
			BIS.B	#NTC_ENABLE,&NTCPDOUT			;Enable the NTC divider
			MOV		#NTC_ACHANNEL,R10				;Channel to be sampled is the NTC one
			CALL	#ADCStartSingle					;Start sampling of NTC divider voltage
			RET


;----------------------------------------
; Interrupt Service Routines
;========================================


;----------------------------------------
; Interrupt Vectors
;========================================

