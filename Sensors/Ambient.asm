;*********************************************************************************************
;* Ambient Temperature and Humidity Library                                                  *
;*-------------------------------------------------------------------------------------------*
;* Ambient.asm                                                                               *
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
;* Library to use a digital humidity sensor to fetch ambient temperature and humidity        *
;* measurements.                                                                             *
;* eliaschr@NOTE: The sensor that will be used is HDC2080.                                   *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"Relays Library"
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
;*===========================================================================================*
;* Predefined Definitions Expected by the Library:                                           *
;* ------------------------------------------------                                          *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "Ambient.h43"			;Local definitions
			.include "AmbientAutoDefs.h43"	;Auto definitions according to settings in
											; Ambient.h43


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


;----------------------------------------
; AmbPInit
; Initialize the ambient sensor's port pins to be used as I2C
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : AMB_SEL0VAL, AMB_SEL1VAL, AMBP_MASK, AMBP_SEL0, AMBP_SEL1
; OTHER FUNCS   : None
AmbPInit:	BIC.B	#AMBP_MASK,&AMBP_SEL0	;Clear the selection bits used byt this I2C
			BIC.B	#AMBP_MASK,&AMBP_SEL1	; in both Special Function Selection registers
			BIS.B	#AMB_SEL0VAL,&AMBP_SEL0	;Now set them as supposed to use them as I2C
			BIS.B	#AMB_SEL1VAL,&AMBP_SEL1
			RET


;----------------------------------------
; AmbI2CInit
; Initialize the I2C bus to be used for Humidity and Temperature sensor
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     :
; OTHER FUNCS   : None
AmbI2CInit: BIS		#UCSWRST,&AMBU_CTLW0	;Keep associated module in reset to configure it
			BIS		#UCMODE_3 | UCMST | UCSYNC,&AMBU_CTLW0
											;Set I2C master mode, in sync
			BIC		#UCASTP_3,&AMBU_CTLW1	;Clear both bits of STOP generation mode
			BIS		#UCASTP_2,&AMBU_CTLW1	;Automatically generate STOP condition when
											; counter reaches its threshold
			MOV		#AMB_BPSDIV,&AMBU_BRW	;Set divider for the correct bit rate
			BIC		#UCSWRST,&AMBU_CTLW0	;Stop reset mode. I2C is ready to be used
			RET


;----------------------------------------
; Interrupt Service Routines
;========================================


;----------------------------------------
; Interrupt Vectors
;========================================

