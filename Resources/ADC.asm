;*********************************************************************************************
;* ADC Library                                                                               *
;*-------------------------------------------------------------------------------------------*
;* ADC.asm                                                                                   *
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
;* Library of procedures for handling the internal ADC of MSP430.                            *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"Analog to Digital Converter Library"
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
			.include "ADC.h43"				;Local definitions
			.include "ADCAutoDefs.h43"		;Auto definitions according to settings in
											; ADC.h43


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
; ADCInit
; Initializes the ADC subsystem
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
ADCInit:	BIC		#ADC12ENC,&ADC12CTL0		;Ensure ENC=0
			;Set the S/H timings and enable ADC module
			MOV		#DEF_ADCSHT1 | DEF_ADCSHT0 | ADC12ON,&ADC12CTL0
			MOV		#ADC12SHP,&ADC12CTL1		;Use the sampling timer, ADC12CLK from MODCLK,
												;Single channel, single conversion
			;Set the resolution and read back format of ADC conversion
			MOV		#DEF_ADCRESOL | DEF_ADCDF,&ADC12CTL2
			;Use the internal temperature and battery channels
			MOV		#ADC12TCMAP | ADC12BATMAP,&ADC12CTL3
			BIS		#ADC12ENC,&ADC12CTL0		;Enable conversions
			RET
			

;----------------------------------------
; Interrupt Service Routines
;========================================


;----------------------------------------
; Interrupt Vectors
;========================================

