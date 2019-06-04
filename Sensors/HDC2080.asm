;*********************************************************************************************
;* HDC2080 Temperature/Humidity Sensor Library                                               *
;*-------------------------------------------------------------------------------------------*
;* HDC2080.asm                                                                               *
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
;* Library of procedures for connecting HDC2080 Temperature/Humidity sensor to the system    *
;* and control it through I2C bus, to make measurements.                                     *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"HDC2080 Temperature/Humidity Sensor Library"
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
			.include "Communications/I2CBus.h43" ;Include I2C support
			.include "HDC2080.h43"			;Local definitions
			.include "HDC2080AutoDefs.h43"	;Auto definitions according to settings in
											; HDC2080.h43


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
; HDCSendRaw
; Sends raw data to HDC2080
; INPUT         : R10 contains the starting register address to be set
;                 R11 contains the number of bytes to be sent
;                 R12 points to the buffer that contains the data to be sent
; OUTPUT        : Carry Flag is set in case of an error
;                 R11 contains the number of bytes remain (0 if everything is OK)
;                 R12 points to the byte just after the one the error occured (Just passed the
;                     buffer of R11 bytes if everything went OK)
; REGS USED     : R4, R5, R10, R11, R12, R15
; REGS AFFECTED : R4, R5, R11, R12, R15
; STACK USAGE   : 4 = 2 for Call, +2 by each called function
; VARS USED     : HDCADDR
; OTHER FUNCS   : I2CSend, I2CStartTx, I2CStop
HDCSendRaw:	MOV		#HDCADDR,R4					;Address the HDC2080
			MOV		#00000h,R5					;Do not use the automatic counter
			CALL	#I2CStartTx					;Send Start condition and Slave address
			JC		HDCSREnd					;In case of an error exit
			MOV		R10,R4						;Send the Register Address
			CALL	#I2CSend
			JC		HDCSREnd					;In case of an error exit
			CMP		#00000h,R11					;Do we have more bytes to send?
			JZ		HDCSREnd					;No => then end the transmission
HDCSRLoop:	MOV.B	@R12+,R4					;Get one byte to be sent
			CALL	#I2CSend					;Send this byte
			JC		HDCSREnd					;In case of an error exit
			DEC		R11							;One byte less
			JNZ		HDCSRLoop					;Repeat if there are more
			CALL	#I2CStop					;Send a Stop condition
HDCSREnd:	RET


;----------------------------------------
; HDCReadRaw
; Reads raw data from HDC2080
; INPUT         : R10 contains the starting register address to be read
;                 R11 contains the number of bytes to be read
; OUTPUT        : Carry flag is set in case of an error
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R15
; STACK USAGE   : 4 = 2 by Call +2 by calling functions
; VARS USED     : HDCADDR
; OTHER FUNCS   : I2CSend, I2CStartRx, I2CStartTx, I2CStop
HDCReadRaw:	MOV		#HDCADDR,R4					;Address the HDC2080
			MOV		#00000h,R5					;Do not use the threshold counter
			CALL	#I2CStartTx					;Send a Start as a transmitter
			JC		HDCRREnd					;In case of an error exit
			MOV		R10,R4						;Register address to start reading from
			CALL	#I2CSend					;Send the address
			JC		HDCRREnd					;In case of an error exit
			MOV		#HDCADDR,R4					;Going to issue a Restart Condition
			MOV		R11,R5						; to receive R11 bytes
			CALL	#I2CStartRx					;Send the Restart condition and fetch R5 bytes
			JC		HDCRREnd					;In case of an error exit
			CALL	#I2CStop					;Then Stop the transaction
HDCRREnd:	RET


;----------------------------------------
; Interrupt Service Routines
;========================================


;----------------------------------------
; Interrupt Vectors
;========================================

