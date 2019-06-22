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
			.cdecls	C,LIST,"msp430.h"			;Include device header file
			.include "Board.h43"				;Hardware Connections
			.include "Definitions.h43"			;Global definitions
			.include "Resources/CRC16.h43"		;Going to use CRC16 library
			.include "Communications/UART.h43"	;UART library to send/receive packets
			.include "UARTProtocol.h43"			;Local definitions
			.include "ProtoAutoDefs.h43"		;Auto definitions according to settings in
												; UARTProtocol.h43


;----------------------------------------
; Definitions
;========================================


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	CurrUID, 2				;Current free UID of a packet
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
;			.global	ISRName


;----------------------------------------
; UARTProtoInit
; Initializes the local variables of the UART Protocol engine
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
UARTProtoInit:
			MOV		#UARTPROTOSEED,&CurrUID	;Reset the UID Seed
			RET


;----------------------------------------
; PrepIndPacket
; Prepares an Indications Packet with data that come from an external buffer
; INPUT         : R11 points to the buffer that holds the indocations data the packet will
;                 contain
; OUTPUT        : None
; REGS USED     : R10, R11, R12
; REGS AFFECTED : R10, R11, R12
; STACK USAGE   : None
; VARS USED     : CurrUID, ID_INDICATIONS, OutPacket, P_IND_DATALEN, P_IND_LEDS_OFFS,
;                 P_IND_LEN, P_LEN_OFFS, P_TYPE_OFFS, P_UID_OFFS
; OTHER FUNCS   : None
PrepIndPacket:
			MOV		#OutPacket,R12			;Target buffer is the Outgoing Packet one
			MOV.B	#P_IND_LEN,P_LEN_OFFS(R12)	;Set the length of the packet
			MOV.B	#ID_INDICATIONS,P_TYPE_OFFS(R12);Set the type of the packet
			ADD		#P_IND_LEN,&CurrUID		;Prepare UID to use
			MOV		&CurrUID,P_UID_OFFS(R12);Set the UID
			MOV		#P_IND_DATALEN,R10		;Length of data to be transfered
PIndPLoop:	MOV.B	@R11+,P_IND_LEDS_OFFS(R12)	;Copy that byte into the Output buffer
			INC		R12						;Also advance the target pointer
			DEC		R10						;One byte less to copy
			JNZ		PIndPLoop				;More bytes => Repeat
			RET
			

;----------------------------------------
; PrepKbdPacket
; Prepares a KeyPress Packet
; INPUT         : R4 contains the keypress
; OUTPUT        : None
; REGS USED     : R12
; REGS AFFECTED : R12
; STACK USAGE   : None
; VARS USED     : CurrUID, ID_KEYPRESS, OutPacket, P_KBD_DUMMYB, P_KBD_KEY_OFFS, P_KBD_LEN,
;                 P_LEN_OFFS, P_TYPE_OFFS, P_UID_OFFS, UARTDUMMY
; OTHER FUNCS   : None
PrepKbdPacket:
			MOV		#OutPacket,R12			;Target buffer is the Outgoing Packet one
			MOV.B	#ID_KEYPRESS,P_TYPE_OFFS(R12);Set the type of the packet
PKBDPMore:	MOV.B	#P_KBD_LEN,P_LEN_OFFS(R12)	;Set the length of the packet
			ADD		#P_KBD_LEN,&CurrUID		;Prepare UID to use
			MOV		&CurrUID,P_UID_OFFS(R12);Set the UID
			MOV		R4,P_KBD_KEY_OFFS(R12)	;Set the keypress data
			MOV		#UARTDUMMY,P_KBD_DUMMYB(R12);Fill in the dummy byte
			RET


;----------------------------------------
; PrepKbdRtrPacket
; Prepares a KeyPress Retransmission Packet
; INPUT         : R4 contains the keypress
; OUTPUT        : None
; REGS USED     : R12
; REGS AFFECTED : R12
; STACK USAGE   : None
; VARS USED     : CurrUID, ID_KEYPRESS, OutPacket, P_KBD_DUMMYB, P_KBD_KEY_OFFS, P_KBD_LEN,
;                 P_LEN_OFFS, P_TYPE_OFFS, P_UID_OFFS, UARTDUMMY
; OTHER FUNCS   : None
PrepKbdRtrPacket:
			MOV		#OutPacket,R12			;Target buffer is the Outgoing Packet one
			MOV.B	#ID_KEYPRESS_RTR,P_TYPE_OFFS(R12);Set the type of the packet
			JMP		PKBDPMore				;The rest are the same as in Keypress packet


;----------------------------------------
; SendPacket
; Calculates the CRC16 and sends the already prepared packet
; INPUT         : None
; OUTPUT        : None
; REGS USED     :
; REGS AFFECTED :
; STACK USAGE   : None
; VARS USED     :
; OTHER FUNCS   : None
SendPacket:
			CALL	#CRC16Init				;Initialize the CRC16 module
			MOV		#OutPacket,R5			;This packet is going to be transmitted
			MOV		@R5,R6					;R6 contains the number of bytes to be used
			SUB 	#00002h,R6				;CRC16 field is not going to be included in the
											; checksum
			CALL	#CRC16AddList			;Calculate the checksum of the packet
			MOV		R4,0(R5)				;Store the CRC16 value
			MOV		#OutPacket,R5			;The totally prepared packet is going to be sent
			MOV		@R5,R6					;R6 contains the size of the packet
			CALL	#UARTSendStream			;Send the packet
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
;ISRName:
;			RETI


;----------------------------------------
; Interrupt Vectors
;========================================
;			.sect	ISR_Vector_Segment
;			.short	ISRName
