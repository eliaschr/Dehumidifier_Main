;*********************************************************************************************
;* I2C Bus Support Library                                                                   *
;*-------------------------------------------------------------------------------------------*
;* I2CBus.asm                                                                                *
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
;* Library that creates the infastructure to use the I2C bus of the microcontroller. It can  *
;* be used to communicate to EEPROMs, Sensorc e.t.c.                                         *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"I2C Bus Support Library"
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
			.include "I2CBus.h43"			;Local definitions
			.include "I2CAutoDefs.h43"		;Auto definitions according to settings in
											; I2CBus.h43


;----------------------------------------
; Definitions
;========================================
;Flags that appear in I2CStatus variable to describe the status of I2C subsystem
I2CBUZY:	.equ	BITF					;I2C Bus is buzy (Transaction in progress)
I2CTRANSMIT:.equ	BITE					;I2C Subsystem sends data


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	I2CTxBuff, I2CTXBUFFLEN *2	;I2C Transmission buffer (contains words)
			.bss	I2CRxBuff, I2CRXBUFFLEN	;I2C Transmission buffer
			.bss	I2CTxStrt, 2			;Starting offset of transmission buffer
			.bss	I2CTxLen, 2				;Length of data in transmission buffer
			.bss	I2CRxStrt, 2			;Starting offset of reception buffer
			.bss	I2CRxLen, 2				;Length of data written in reception buffer
			.bss	I2CStatus, 2			;Some status flags

;When debugging the subsystem, the variables should be global in order for CCS to address them
; When debugging uncomment the following lines
;			.global	I2CTxBuff
;			.global	I2CRxBuff
;			.global	I2CTxStrt
;			.global	I2CTxLen
;			.global	I2CRxStrt
;			.global	I2CRxLen
;			.global	I2CStatus


;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text
			.global	I2CDispatcher			;ISRs should be global


;----------------------------------------
; I2CPInit
; Initialize the associated eUSCI pins to be used as I2C
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2C_SEL0VAL, I2C_SEL1VAL, I2CP_MASK, I2CP_SEL0, I2CP_SEL1
; OTHER FUNCS   : None
I2CPInit:	BIC.B	#I2CP_MASK,&I2CP_SEL0	;Clear the selection bits used byt this I2C
			BIC.B	#I2CP_MASK,&I2CP_SEL1	; in both Special Function Selection registers
			BIS.B	#I2C_SEL0VAL,&I2CP_SEL0	;Now set them as supposed to use them as I2C
			BIS.B	#I2C_SEL1VAL,&I2CP_SEL1
			RET


;----------------------------------------
; I2CInit
; Initialize the I2C bus to be used for Humidity and Temperature sensor
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2C_BPSDIV, I2CBUZY, I2CStatus, I2CU_BRW, I2CU_CTLW0, I2CU_CTLW1
; OTHER FUNCS   : None
I2CInit:	BIS		#UCSWRST,&I2CU_CTLW0	;Keep associated module in reset to configure it
			BIC		#I2CBUZY,&I2CStatus		;Bus is free
			BIS		#UCMODE_3 | UCMST | UCSYNC,&I2CU_CTLW0
											;Set I2C master mode, in sync
			BIC		#UCASTP_3,&I2CU_CTLW1	;Clear both bits of STOP generation mode (No auto-
											; matic STOP condition)
			MOV		#I2C_BPSDIV,&I2CU_BRW	;Set divider for the correct bit rate
			BIC		#UCSWRST,&I2CU_CTLW0	;Stop reset mode. I2C is ready to be used
			RET
			

;----------------------------------------
; I2CStartTx
; Produces a Start condition on I2C bus and sends the Address byte. After that, it is ready to
; transmit more bytes
; INPUT         : R4 contains the Slave to be addressed
; OUTPUT        : If everything is fine, the carry flag is cleared. If the consition is not
;                 sent or it is not scheduled
; REGS USED     : R4, R15
; REGS AFFECTED : R4, R15
; STACK USAGE   : 2
; VARS USED     : I2CBUZY, I2CTxBuff, I2CTxStrt, I2CStatus, I2CTxLen, I2CTXBUFLEN, I2CU_CTLW0,
;                 I2CU_I2CSA, I2CU_IE, I2CU_IFG
; OTHER FUNCS   : None
I2CStartTx:	BIT		#I2CBUZY,&I2CStatus		;Is the bus buzy?
			JZ		I2CSTTTx				;No => Start the communication at once
			BIC		#UCTXIE0,&I2CU_IE		;Disable transmission interrupt
			BIT		#UCTXIFG0,&I2CU_IFG		;is the transmission sybsystem in use?
			JZ		I2CTxSchdSt				;Yes => then schedule the transmission
			CMP		#00000h,&I2CTxLen		;Is there any scheduled data to be transmitted?
			JNZ		I2CTxSchdSt				;Yes => Schedule this transmission
			;At this point, either the bus is free, or it expects data to be transmitted (all
			; the previous scheduled data were transmitted and wait for the next action).
			; The bus must be used at once
I2CSTTTx:	MOV		R4,&I2CU_I2CSA			;Set the slave address to be transmitted
			BIS		#UCTR,&I2CU_CTLW0		;Going to transmit data to the slave
			BIS		#UCTXSTT,&I2CU_CTLW0	;Generate the Start condition and send the address
			BIS		#I2CBUZY | I2CTRANSMIT,&I2CStatus
											;The bus now is buzy transmitting data
			BIS		#UCTXIE0,&I2CU_IE		;Enable the transmission interrupt
			CLRC							;Clear carry to signal success
			RET
			;The bus should schedule the byte, by adding it in the transmission buffer. This
			; is a critical task, as a running interrupt could alter the results and create a
			; lockup making the bus unusable. So, at this point the Tx interrupt must be
			; disabled
I2CTxSchSt:	BIS		#(UCTXSTT | UCTR) <<8,R4;Set that this is a starting condition of the
											; Tx communication
I2CTx_Schd:	PUSH	SR						;Store the general interrupts status
			DINT							;Disable them. The following part is critical
			CMP		#I2CTXBUFLEN,&I2CTxLen	;Is there any empty cell in buffer?
			JHS		I2CTxStErr				;No => Flag the error and exit
			MOV		&I2CTxStrt,R15			;Get the starting of the cyclic buffer
			ADD		#I2CTxLen,R15			;Add the stored data in it to find the first empty
											; cell
			CMP		#I2CTXBUFLEN,R15		;Passed the end of the buffer?
			JLO		I2CTxNoRvrt				;No => then do not revert to the beginning
			SUB		#I2CTXBUFLEN,R15		;else, revert to the beginning
I2CTxNoRvrt:
			ADD		#I2CTxBuff,R15			;R15 points to the first empty cell to be used
			MOV		R4,0(R15)				;Store the whole word of data + flags
			INCD	&TXBufLen				;Increase the occupied length in buffer (Word)
			POP		SR						;Restire interrupts status
			CLRC							;Clear carry to flag success
			BIS		#UCTXIE0,&I2CU_IE		;Enable transmission interrupt again
			RET
										
			;Buffer is full. The starting slave address is not scheduled => Error
I2CTxStErr:	POP		SR						;Restore general interrupt status
			BIS		#UCTXIE0,&I2CU_IE		;Enable the transmission interrupt
			SETC							;Set carry flag to express there was an error
			RET
			

;----------------------------------------
; I2CSend
; Sends a byte when the I2C subsystem is configured as a transmitter
; INPUT         : R4 contains the byte to be transmitted
; OUTPUT        : If everything is fine, the carry flag is cleared. If the consition is not
;                 sent or it is not scheduled
; REGS USED     : R4, R15 (Through I2CTx_Schd)
; REGS AFFECTED : R4, R15
; STACK USAGE   : 2 (by I2CTx_Schd)
; VARS USED     : I2CBUZY, I2CStatus, I2CTXBUF, I2CTxLen, I2CU_IE, I2CU_IFG
; OTHER FUNCS   : I2CTx_Schd
I2CSend:	BIT		#I2CBUZY,&I2CStatus		;Is the bus buzy?
			JZ		I2CTxNow				;No => Send the data at once
			BIC		#UCTXIE0,&I2CU_IE		;Disable transmission interrupt
			BIT		#UCTXIFG0,&I2CU_IFG		;is the transmission sybsystem in use?
			JZ		I2CTxSchdD				;Yes => then schedule the transmission
			CMP		#00000h,&I2CTxLen		;Is there any scheduled data to be transmitted?
			JNZ		I2CTxSchdD				;Yes => Schedule this transmission
			;At this point, either the bus is free, or it expects data to be transmitted (all
			; the previous scheduled data were transmitted and wait for the next action).
			; The bus must be used at once
I2CTxNow:	MOV.B	R4,&I2CTXBUF			;Send it at once
			BIS		#UCTXIFG0,I2CU_IE		;Enable the transmission interrupt
			CLRC							;Clear carry flag to signal the validity
			RET
			;The bus should schedule the byte, by adding it in the transmission buffer. This
			; is a critical task, as a running interrupt could alter the results and create a
			; lockup making the bus unusable. So, at this point the interrupts must be
			; disabled
I2CTxSchdD:	BIC		#0FF00h,R4				;Ensure higher byte of R4 is cleared as this is
											; pure data
			JMP		I2CTx_Schd				;Schedule the new data to be transmitted later


;----------------------------------------
; I2CStop
; Sends a Stop condition through the I2C bus
; INPUT         : None
; OUTPUT        : If everything is fine, the carry flag is cleared. If the consition is not
;                 sent or it is not scheduled
; REGS USED     : R4, R15 (by I2CTx_Schd)
; REGS AFFECTED : R4, R15 (by I2CTx_Schd)
; STACK USAGE   : 2 (by I2CTx_Schd)
; VARS USED     : I2CBUZY, I2CStatus, I2CTXBUF, I2CTxLen, I2CU_IE, I2CU_IFG
; OTHER FUNCS   : I2CTx_Schd
I2CStop:	BIT		#I2CBUZY,&I2CStatus		;Is the bus buzy?
			JZ		I2CStpTxNow				;No => Send the data at once
			BIC		#UCTXIE0,&I2CU_IE		;Disable transmission interrupt
			BIT		#UCTXIFG0,&I2CU_IFG		;is the transmission sybsystem in use?
			JZ		I2CSpSchdD				;Yes => then schedule the transmission
			CMP		#00000h,&I2CTxLen		;Is there any scheduled data to be transmitted?
			JNZ		I2CSpSchdD				;Yes => Schedule this transmission
			;At this point, either the bus is free, or it expects data to be transmitted (all
			; the previous scheduled data were transmitted and wait for the next action).
			; The bus must be used at once
I2CStpTxNow:
			BIS		#UCTXSTP,&I2CU_CTLW0	;Generate the Stop Condition
			BIS		#UCSTPIFG,&I2CU_IE		;Enable the Stop Condition Interrupt
			CLRC							;Signal everything is OK
			RET
			;The bus should schedule the transaction, by adding it in the transmission buffer
			; an empty byte with the stop condition flag set. This is a critical task, as a
			; running interrupt could alter the results and create a lockup making the bus
			; unusable. So, at this point the interrupts must be disabled
I2CSpSchdD:	MOV		#UCTXSTP << 8,R4		;Set R4 with empty data and Stop Condition flag
			JMP		I2CTx_Schd				;Schedule the new data to be transmitted later


;----------------------------------------
; I2CStartRx
; Produces a Start condition on I2C bus and sends the Address byte. The bus is configured in
; Receiver mode, so it expects to receive data from the slave
; INPUT         : R4 contains the Slave to be addressed
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2CU_CTLW0, I2CU_I2CSA
; OTHER FUNCS   : None
I2CStartRx:	BIT		#I2CBUZY,&I2CStatus		;Is the bus buzy?
			JZ		I2CSTTRx				;No => Start the communication at once
			BIC		#UCTXIE0,&I2CU_IE		;Disable transmission interrupt
			BIT		#UCTXIFG0,&I2CU_IFG		;is the transmission sybsystem in use?
			JZ		I2CRxSchdSt				;Yes => then schedule the transmission

			CMP		#00000h,&I2CTxLen		;Is there any scheduled data to be transmitted?
			JNZ		I2CRxSchdSt				;Yes => Schedule this transmission
			;At this point, either the bus is free, or it expects data to be transmitted (all
			; the previous scheduled data were transmitted and wait for the next action).
			; The bus must be used at once
I2CSTTRx:	MOV		R4,&I2CU_I2CSA			;Set the slave address to be transmitted
			BIC		#UCTR,&I2CU_CTLW0		;Going to receive data to the slave
			BIS		#UCTXSTT,&I2CU_CTWL0	;Generate the Start condition and send the address
			BIS		#I2CBUZY,&I2CStatus
			BIC		#I2CTRANSMIT,&I2CStatus
											;The bus now is buzy transmitting data
			RET
			;The bus should schedule the transaction, by adding it in the transmission buffer.
			; Adding the slave address with the starting flag enabled is the indication of a
			; scheduled receiver transaction. This is a critical task, as a running interrupt
			; could alter the results and create a lockup making the bus unusable. So, at this
			; point the interrupts must be disabled
I2CSpSchdD:	MOV		#UCTXSTT << 8,R4		;Set R4 with empty data and Start Condition flag
			JMP		I2CTx_Schd				;Schedule the new data to be transmitted later


;----------------------------------------
; I2CReadBuf
; Reads a byte from the reception buffer, if there is any
; INPUT         : None
; OUTPUT        : R4 contains the byte read from I2C Reception Buffer. If there was no data
;                  available, R4 is reset and Carry Flag is set.
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : 
; OTHER FUNCS   : None
I2CReadBuf:	MOV.B	#000h,R4
			CMP		#00000h,&I2CRxLen
			JNE		I2CRxNo
			PUSH	SR						;Store the state of the interrupts
			DINT							;Disable them. The following is a critical section
			MOV		&I2CRxStrt,R4			;Get the starting pointer
			ADD		#I2CRxBuff,R4			;Add the starting offset of the buffer
			MOV.B	@R4,R4					;Get the byte from the buffer
			DEC		&I2CRxLen				;One byte less in buffer
			POP		SR						;Restore Interrupts
			CLRC							;Clear carry. R4 contains a byte
I2CRxNo:	;SETC							;Came here from a CMP #O,... When 0, the carry
											; flag is set, so no need to do it again here.
											; Added only for clarity
			RET


;----------------------------------------
; Interrupt Service Routines
;========================================
;----------------------------------------
; I2CTxISR
; Interrupt Service Routine for I2C Transmission readiness. The interrupt is triggered by
; UCTXIFG0 flag when its associated interrupt is enabled (UCTXIE0) and the system is ready to
; accept a new data byte to be transmitted. If there is any byte in the buffer it should be
; sent now.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : None
; OTHER FUNCS   : None
I2CTxISR:	
			CMP		#00000h,&I2CTxLen		;Is there any scheduled data to be transmitted?
			JZ		ITxISRExit				;No => Then exit the interrupt
			PUSH	R4						;Gonna need some registers
			PUSH	R15
			MOV		&I2CTxStrt,R15			;Get the starting offset of the buffer
			MOV		I2CTxBuf(R15),R4		;Get the word scheduled
			INCD	R15						;Point to the next element in buffer
			CMP		#I2CTXBUFFLEN,R15		;Passed the border of the table?
			JLO		ITxNoRvt				;No => do not revert to the beginning
			MOV		#00000h,R15				;else, point to the beginning of the table
ITxNoRvt:	MOV		R15,&I2CTxStrt			;Store the new pointer
			DECD	&I2CTxLen				;One word less in the buffer
			JNZ		ITxISRKeep				;Still data in buffer? => Keep this ISR enabled
			BIC		#UCTXIE0,&I2CU_IE		;else, disable it
			;Now R4 contains the data byte to be sent at its LSB and the control flags at its
			; MSB. Need to see the flags to figure out if this is a data byte to be send or
			; something else
ITxISRKeep:	BIT		#(UCTXSTP << 8),R4		;Do we have to send a Stop Condition?
			JNZ		ITxISRStp				;Yes => then do it
			BIT		#(UCTXSTT << 8),R4		;Do we have to send a Start Condition?
			JNZ		ITxISRStt				;Yes => Send a reStart Condition
			;Just a clear byte to send
			MOV.B	R4,&I2CU_TXBUF			;Go!...
			POP		R15						;And exit, restoring the used registers
			POP		R4
			RETI
			
ITxISRStt:	;If a Start Condition is scheduled then R4 at its LSB contains the slave to be
			; addressed and at its MSB there is the UCRX flag
			MOV.B	R4,&I2CU_I2CSA			;Set the slave address
			BIC		#UCRX,&I2CU_CTLW0		;Clear the Receiver Mode bit
			AND		#(UCRX << 8),R4			;Keep only this bit in R4 MSB
			SWPB							;Bring the control word at LSB
			BIS		R4,&I2CU_CTLW0			;Set the Receiver Mode according to the setup
			BIS		#UCTXSTT,&I2CU_CTLW0	;Send the Start Condition and the slave address
			POP		R15						;And exit, restoring the used registers
			POP		R4
			RETI

ITxISRStp:	;When a Stop Condition is scheduled, the lower byte of R4 is irrelevant
			BIS		#UCTXSTP,&I2CU_CTLW0	;Send the Stop Condition (and wait for its
											; interrupt
			POP		R15						;Restore used registers
			POP		R4

ITxISRExit:	
			RETI
			

;----------------------------------------
; I2CDispatcher
; Interrupt Service Routine for I2C eUSCI. It dispatches to the appropriate function according
; to the Interrupt Vector that triggered the interrupt
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : I2CU_IV
; OTHER FUNCS   : I2CNAckISR, I2CRxISR, I2CStpISR, I2CTxISR
I2CDispatcher:
			ADD		&I2CU_IV,PC				;Proceed to appropriate Jump
			RETI							;Vector 0: No Interrupt
			RETI							;Vector 2: Arbitration Lost (ALIFG)
			JMP		I2CNAckISR				;Vector 4: Not Acknowledge received (NACKIFG)
			RETI							;Vector 6: Start Condition met (Slave, STTIFG)
			JMP		I2CStpISR				;Vector 8: Stop Condition met (STPIFG)
			RETI							;Vector 10: RXIFG3
			RETI							;Vector 12: TXIFG3
			RETI							;Vector 14: RXIFG2
			RETI							;Vector 16: TXIFG2
			RETI							;Vector 18: RXIFG1
			RETI							;Vector 20: TXIFG1
			JMP		I2CRxISR				;Vector 22: Byte received (RXIFG0)
			JMP		I2CTxISR				;Vector 24: Byte transmitted (TXIFG0)
			RETI							;Vector 26: Byte Counter interrupt (BCNTIFG)
			RETI							;Vector 28: Clock Low Timeout (CLTOIFG)
			RETI							;Vector 30: 9th Bit Transferring (BIT9IFG)
			

;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	I2CU_Vector
			.short	I2CDispatcher
