;*********************************************************************************************
;* UART - RS232 Library                                                                      *
;*-------------------------------------------------------------------------------------------*
;* UART.asm                                                                                  *
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
;* Library needed for RS232 connectivity to other hardware subsystems.                       *
;*********************************************************************************************
;* Note: Correct format of the file is presented when tab space is set to 4
			.title	"UART - RS232 Library"
			.width	94
			.tab	4

;*===========================================================================================*
;* Names And Values:                                                                         *
;* ------------------                                                                        *
;* The UARTFlags variable is consisted of bit flags that present the current status of the   *
;* UART subsystem. Their meanings are explained in the following definitions                 *
;* RSServe   : Flags that RS232 subsystem needs attention                                    *
;* RSRxError : Flags that a character was received while the buffer was full                 *
;* RS0A      : Last character received was 0Ah (perhaps part of a newline character)         *
;* RS0D      : Last character received was 0Dh (perhaps part of a newline character)         *
;* RSRxEol   : Flags that the system has just received a new line character (force wake up   *
;*              by RX ISR)                                                                   *
;* RSBinary  : Flags binary mode. It does not filter any characters and the wake up is       *
;*              controlled by timer                                                          *
;* RSPacket  : Flags packet mode. As in binary mode, it doesnot filter the incoming data but *
;*              the first byte received is considered a length of packet field. After        *
;*              receiving this number of bytes it wakes the system up to consume the packet. *
;*                                                                                           *
;*===========================================================================================*
;* Variables:                                                                                *
;* -----------                                                                               *
;* UARTFlags     : Flags to control the functionality of RS232 subsystem                     *
;* UARTTxStrt    : Offset in transmition buffer of the first character to be transmitted     *
;* UARTTxLen     : Length of data waiting to be sent in the transmition buffer               *
;* UARTRxStrt    : Offset in reception buffer of the first character received earlier by     *
;*                  RS232                                                                    *
;* UARTRxLen     : Number of bytes waiting to be read in the reception buffer                *
;* UARTWakeLim   : The wake up buffer limit. When the receiving buffer reaches this limit it *
;*                  wakes up the system to handle received data                              *
;* UARTPacketLen : The number of bytes remaining to complete the incoming packet             *
;* UARTPacketQ   : The number of complete packets received in the input buffer               *
;* UARTTxCBuf    : Cyclic buffer to hold the data to be sent                                 *
;* UARTRxCBuf    : Cyclic buffer to hold the data received                                   *
;*                                                                                           *
;*===========================================================================================*
;* Functions of the Library:                                                                 *
;* --------------------------                                                                *
;* UARTPInit       : Initialises the port pins used for the serial bus                       *
;* UARTCInit       : Initialises the USCI that is used for RS232 communications              *
;* UARTSysInit     : Initialises the UART-RS232 system variables and Timer module            *
;* UARTEnableInts  : Enables the receiving interrupt of UART                                 *
;* UARTDisableInts : Disables the receiving interrupt of UART                                *
;* UARTSetBinMode  : Sets the systen to binary mode, no EOL filtering is done, data are      *
;*                    considered binary                                                      *
;* UARTSetTxtMode  : Sets the system to Text mode. EOL filtering is performed by checking    *
;*                    the existance of at least one character of CR or LF (or both)          *
;* UARTGetMode     : Returnes the current mode of reception (text or binary)                 *
;* UARTSetupTimer  : Starts or restarts the timeout reception timer                          *
;* UARTCheckServe  : Checks if there is the need to consume received data                    *
;* UARTSendStream  : Sends a whole stream of data                                            *
;* UARTSend        : Sends a byte of data to the UART stream                                 *
;* UARTReceive     : Gets the current byte from the reception queue                          *
;* UARTTimerISR    : The TimerA timeout interrupt service routine                            *
;* UARTTxISR       : Transmission interrupt service routine                                  *
;* UARTRxISR       : Reception interrupt service routine                                     *
;* UARTIDispatcher : UART Interrupt Service Dispatcher. The interrupt of the UART is multi-  *
;*                    plexed, so the dispatcher looks which one is the source of the         *
;*                    interrutp and dispatches the code to the correct service routine       *
;*                                                                                           *
;*********************************************************************************************
			.cdecls	C,LIST,"msp430.h"		;Include device header file
			.include "Board.h43"			;Hardware Connections
			.include "Definitions.h43"		;Global definitions
			.include "UART.h43"				;Local definitions
			.include "UARTAutoDefs.h43"		;Auto definitions according to settings in
											; UART.h43


;----------------------------------------
; Definitions
;========================================
RSServe:	.equ	BIT0					;Flags that RS232 subsystem needs attention
RSRxError:	.equ	BIT1					;Flags that a character was received while the
											; buffer was full
RS0A:		.equ	BIT2					;Last character received was 0Ah (perhaps part of
											; a newline character)
RS0D:		.equ	BIT3					;Last character received was 0Dh (perhaps part of
											; a newline character)
RSRxEol:	.equ	BIT4					;Flags that the system has just received a new
											; line character (force wake up by RX ISR)
RSBinary:	.equ	BIT5					;Flags binary mode. It does not filter any
											; characters and the wake up is controlled by
											; timer
RSPacket:	.equ	BIT6					;Flags packet mode. It does not filter any
											; characters like binary mode, but the first byte
											; received is considered as the number of bytes
											; that form a complete packet. After receiving
											; the whole packet, it wakes the system up to
											; consule it.
RSStrTrnc:	.equ	BIT7					;Stream is truncated
RSPcktCont:	.equ	BIT8					;Need to continue a packet previously received but
											; not completed


;*********************************************************************************************
; Variables Definitions
;-------------------------------------------
			.bss	UARTFlags, 2			;Flags to control the functionality of RS232
											; subsystem
			.bss	UARTTxStrt, 2			;Offset in transmition buffer of the first
											; character to be transmitted
			.bss	UARTTxLen, 2			;Length of data waiting to be sent in the
											; transmition buffer
			.bss	UARTRxStrt, 2			;Offset in reception buffer of the first character
											; received earlier by RS232
			.bss	UARTRxLen, 2			;Number of bytes waiting to be read in the
											; reception buffer
			.bss	UARTWakeLim, 2			;The wake up buffer limit. When the receiving
											; buffer reaches this limit it wakes up the system
											; to handle received data
			.bss	UARTPacketLen, 2		;The number of bytes need to receive in order to
											; complete a whole packet
			.bss	UARTStreamLen, 2		;The length of the current packet receiving (by
											; UARTReceiveStream)
			.bss	UARTPacketQ, 2			;The number of packets
			.bss	UARTTxCBuf, UARTTXSIZE	;Cyclic buffer to hold the data to be sent
			.bss	UARTRxCBuf, UARTRXSIZE	;Cyclic buffer to hold the data received


;----------------------------------------
; Constants
;========================================


;----------------------------------------
; Functions
;========================================
			.text
;Interrupt Service Routines must be global
			.global	UARTIDispatcher
			.global	UARTTimerISR


;----------------------------------------
; UARTPInit
; Initialises the port pins used for the serial bus
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : COMM_ALL, COMM_SEL0, COMM_SEL0VAL, COMM_SEL1, COMM_SEL1VAL
; OTHER FUNCS   : None
UARTPInit:
			BIC.B	#COMM_ALL,&COMM_SEL0	;Clear the selector flags
			BIC.B	#COMM_ALL,&COMM_SEL1
			BIS.B	#COMM_SEL0VAL,&COMM_SEL0;Set them according to the selected eUSCI_A port
			BIS.B	#COMM_SEL1VAL,&COMM_SEL1
			RET


;----------------------------------------
; UARTCInit
; Initialises the USCI that is used for RS232 communications
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : BRx, CTL0VAL, CTL1VAL, MCTLVAL, COMM_BRW, COMM_CTLW0, COMM_CTLW1, COMM_MCTLW
; OTHER FUNCS   : None
UARTCInit:
			BIS.B	#UCSWRST,&COMM_CTLW1	;Keep USCI in reset mode
			MOV.B	#BRx,&COMM_BRW			;Set the baud rate prescaler
			MOV.B	#CTL0VAL,&COMM_CTLW0	;Set Data format
			MOV.B	#CTL1VAL,&COMM_CTLW1	;Set the control of the bus
			MOV.B	#MCTLVAL,&COMM_MCTLW	;Set the Modulation Control register
			BIC.B	#UCSWRST,&COMM_CTLW1	;Release Serial module
			RET


;----------------------------------------
; UARTSysInit
; Initialises the UART-RS232 system variables and Timer module
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : COMMTCCR1, COMMTCCTL1, UARTFlags, UARTRxLen, UARTRxStrt, UARTRXWAKELIM,
;                 UARTTxLen, UARTTxStrt, UARTWakeLim
; OTHER FUNCS   : None
UARTSysInit:
			MOV		#000h,&UARTTxStrt		;Move starting pointer to the beginning of buffer
			MOV		#000h,&UARTTxLen		;Transmition buffer does not contain data
			MOV		#000h,&UARTRxStrt		;Move starting pointer to the beginning of buffer
			MOV		#000h,&UARTRxLen		;Reception buffer does not contain data
			MOV		#00000h,&UARTFlags		;Reset flags

			MOV		#UARTRXWAKELIM,&UARTWakeLim	;Setup the default wake up limit
			
			MOV		#TASSEL_1,&COMMTCTL		;Timer is clocked by AClk (32768)
			MOV		#00000h,&COMMTR			;Clear "Now"
			MOV		#00000h,&COMMTCCTL0		;Compare mode, no interrupts (yet)
			MOV		#00000h,&COMMTEX0		;No extension to input clock divider
			MOV		#UARTWAKEUPTICKS,&COMMTCCR0	;Set the point of interrupt to 10 characters
			RET


;----------------------------------------
; UARTEnableInts
; Enables the receiving interrupt of RS232
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : COMM_IE, COMM_IFG
; OTHER FUNCS   : None
UARTEnableInts:
			BIC.B	#UCRXIFG,&COMM_IFG		;Clear any pending interrupts of UCAxRX
			BIS.B	#UCRXIE,&COMM_IE		;Enable the reception interrupt of RS232
			RET


;----------------------------------------
; UARTDisableInts
; Disables the receiving interrupt of UART. Transmition interrupt is disabled automatically
; when there is no data to be sent
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : COMM_IE, COMM_IFG
; OTHER FUNCS   : None
UARTDisableInts:
			BIC.B	#UCRXIFG,&COMM_IFG		;Clear any pending interrupts of UCAxRX
			BIC.B	#UCRXIE,&COMM_IE		;Disable the reception interrupt of RS232
			RET


;----------------------------------------
; UARTSetBinMode
; Sets the receiving mode to Binary. No data is filtered upon receiving. Timer wakes up the
; system to handle the received data
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RSBinary, UARTFlags
; OTHER FUNCS   : None
UARTSetBinMode:
			BIC		#RSPacket,&UARTFlags	;Clear possible packet mode
			BIS		#RSBinary,&UARTFlags	;Set binary flag
			RET


;----------------------------------------
; UARTSetTxtMode
; Sets the receiving mode to text. New line sequences are filtered. No timer is used
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RSBinary, UARTFlags
; OTHER FUNCS   : None
UARTSetTxtMode:
			BIC		#CCIE | CCIFG,&COMMTCCTL1;Disable timer interrupt in this mode
			BIC		#RSBinary | RSPacket,&UARTFlags	;Clear binary an packet flags
			RET


;----------------------------------------
; UARTSetPcktMode
; Sets the receiving mode to text. New line sequences are filtered. No timer is used
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RSBinary, UARTFlags
; OTHER FUNCS   : None
UARTSetPcktMode:
			BIC		#CCIE | CCIFG,&COMMTCCTL1;Disable timer interrupt in this mode
			BIC		#RSBinary,&UARTFlags	;Clear binary flag
			BIS		#RSPacket,&UARTFlags	;Set the packet flag
			RET


;----------------------------------------
; UARTGetMode
; Gets the receiving mode
; INPUT         : None
; OUTPUT        : R4 contains the current mode
; REGS USED     : R4
; REGS AFFECTED : R4
; STACK USAGE   : None
; VARS USED     : RSBinary, RSPacket, UARTFlags
; OTHER FUNCS   : None
UARTGetMode:
			MOV		&UARTFlags,R4			;Get the flags
			AND		#RSPacket | RSBinary,R4	;Filter only the mode bits
			RET


;----------------------------------------
; UARTSetupTimer
; (Re)Starts the timeout timer counting for binary reception.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 2 = 1x Push
; VARS USED     : COMMTCCR0, COMMTCTL, COMMTCCTL0, COMMTR, UARTWAKEUPTICKS
; OTHER FUNCS   : None
UARTSetupTimer:
			PUSH	SR						;Keep the state of general interrupts flag
			DINT							;Timer should not disturb us
			NOP
			MOV		#UARTWAKEUPTICKS,&COMMTCCR0	;Set the offset in timer ticks
			ADD		#COMMTR,&COMMTCCR0		;Add "Now"
			BIC		#CCIFG,&COMMTCCTL0		;No pending interrupt from timer CCR0 limit
			BIS		#CCIE,&COMMTCCTL0		;Enable interrut of CCR0 limit
			BIS		#MC_2,&COMMTCTL			;Start in Continuous mode
			POP		SR						;Restore interrupt state
			RET


;----------------------------------------
; UARTCheckServe
; Gets the status of Serve flag. After reading the RSServe flag, it resets it
; INPUT         : None
; OUTPUT        : Carry flag is set on need to get the reception buffer's data
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : RSServe, UARTFlags
; OTHER FUNCS   : None
UARTCheckServe:
			BIT		#RSServe,&UARTFlags		;Carry flag contains the value of Serve flag
			BIC		#RSServe,&UARTFlags		;Clear this flag
			RET


;----------------------------------------
; UARTSendStream
; Sends a whole stream of data to the RS232 bus. If the buffer is full it waits until is is
; free to send the necessary bytes. So, the call is blocking if needed
; INPUT         : R5 points to the buffer that contains the data to be sent
;                 R6 contains the length of the stream in bytes
; OUTPUT        : None
; REGS USED     : R4, R5, R6, R8 (from UARTSend)
; REGS AFFECTED : R4, R5, R6, R8
; STACK USAGE   : 4 = 1x Call + 2 bytes by called function
; VARS USED     : UARTTxLen, UARTTXSIZE
; OTHER FUNCS   : UARTSend
UARTSendStream:
			CMP		#00000h,R6				;Are there any bytes to be sent?
			JZ		USS_Exit				;No => Exit
			MOV.B	@R5+,R4					;Get the byte to be transmitted
USS_Cont:	CALL	#UARTSend				;Send the byte
			JC		USS_Error				;Carry flag set? => Buffer full... need to wait
			DEC		R6						;One byte less to send
			JMP		UARTSendStream			;Restart
USS_Error:	CMP		#UARTTXSIZE,&UARTTxLen	;Is the buffer full?
			JHS		USS_Error				;Yes => Repeat check until there is an empty cell
			JMP		USS_Cont
USS_Exit:	RET


;----------------------------------------
; UARTSend
; Sends a byte to the RS232 bus
; INPUT         : R4 contains the byte to be sent
; OUTPUT        : Carry flag is set on error (buffer full), cleared on success
; REGS USED     : R4
; REGS AFFECTED : R8
; STACK USAGE   : 2 = 1x Push
; VARS USED     : COMM_IE, COMM_IFG, COMM_TXBUF, UARTTxCBuf, UARTTxLen, UARTTXSIZE, UARTTxStrt
; OTHER FUNCS   : None
UARTSend:
			CMP		#000h,&UARTTxLen		;Do we have characters in the buffer?
			JZ		RSS_Send				;No => Try to send the byte at once
			CMP		#UARTTXSIZE,&UARTTxLen	;Is the buffer full?
			JHS		RSS_Exit				;Yes => exit with carry flag set
			PUSH	SR						;Store the state of interrupts
			DINT							;Pause interrupts for a little bit
			NOP
RSS_Store:	MOV		&UARTTxStrt,R8			;Get the strting offset of the first character
			ADD		&UARTTxLen,R8			;Add the length of data stored in the buffer to
											; find the first empty cell in it
			POP		SR						;Restore interrupts
			CMP		#UARTTXSIZE,R8			;Passed the end of physical buffer?
			JLO		RSSNoRvt				;No => Do not revert to its beginning
			SUB		#UARTTXSIZE,R8			;else bring it inside buffer's bounds
RSSNoRvt:	MOV.B	R4,UARTTxCBuf(R8)		;Store the byte into the buffer
			INC		&UARTTxLen				;Increment the stored buffer data length by one
			CLRC							;Clear carry to flag success
RSS_Exit:	RET
RSS_Send:	PUSH	SR						;Store interrupts' status
			DINT							;Disable them
			NOP
			BIT.B	#UCTXIFG,&COMM_IFG		;Is the buffer in use?
			JZ		RSS_Store				;Yes => Store the byte for later transmition
			POP		SR						;Restore interrupts' status
			MOV.B	R4,&COMM_TXBUF			;Send it now
			BIS.B	#UCTXIE,&COMM_IE		;Enable transmit interrupt
			CLRC							;Clear carry to flag success
			RET								;and exit


;----------------------------------------
; UARTReceive
; Fetches a byte from the RS232 reception buffer
; INPUT         : None
; OUTPUT        : R4 contains the byte fetched. Carry flag is set on error (buffer empty) or
;                 cleared on success
; REGS USED     : R4, R11
; REGS AFFECTED : R4, R11
; STACK USAGE   : 2 = 1x Push
; VARS USED     : UARTRxCBuf, UARTRxLen, UARTRXSIZE, UARTRxStrt
; OTHER FUNCS   : None
UARTReceive:
			CMP		#00000h,&UARTRxLen		;Is there any data in the receiving buffer?
			JZ		RSRecFail				;No => exit with carry flag set
			MOV		&UARTRxStrt,R11			;Get the starting offset of the first character
			MOV.B	UARTRxCBuf(R11),R4		;Get this byte
			PUSH	SR						;Store the state of interrupts
			DINT							;Both start and length should be changed before
											; another process use them
			NOP
			DEC		&UARTRxLen				;One character less in the buffer
			INC		R11						;Advance the starting pointer to the next stored
											; character
			CMP		#UARTRXSIZE,R11			;Crossed the physical buffer's boundary?
			JLO		RSRecNoRvt				;No => do not revert to the beginning
			MOV		#00000h,R11				;else, move pointer to the beginning of the buffer
RSRecNoRvt:	MOV		R11,&UARTRxStrt			;Store the starting pointer
			POP		SR						;Restore interrupts
			CLRC							;Flag success
RSRecFail:	RET								;and return to caller


;----------------------------------------
; UARTReceiveStream
; Fetches a stream of bytes from the RS232 reception buffer and copies them to a destination
; buffer. If the subsystem is in packet mode, it stops when a packet is completed or the
; destination buffer is full.
; INPUT         : R5 points to the target buffer
;                 R6 contains the maximum size of the destination buffer
;                 Carry flag, if UART is in Packet Mode, presents if there is the need to
;                 start fetching a new packet (Carry flag cleared) or continue fetching a
;                 previously started one (Carry flag set). Does not bother in other modes
; OUTPUT        : R15 contains the number of bytes fetched.
;                 Carry flag is set if the destination buffer is full and there are more bytes
;                 to be fetched. This means that if the system is in packet mode, there is at
;                 least one more complete packet in the buffer to be received.
; REGS USED     : R4, R5, R6, R10, R11, R15
; REGS AFFECTED : R4, R5, R6, R10, R11, R15
; STACK USAGE   : 4 = 1x Call + 2 by calling function
; VARS USED     : UARTRxCBuf, UARTRxLen, UARTRXSIZE, UARTRxStrt
; OTHER FUNCS   : UARTReceive, UARTReceiveBin, UARTReceiveLine
UARTReceiveStream:
			;First lets decide the number of bytes to be copied. This number is the minimum of
			; the destination buffer's size, the packet length (or the line length) that is in
			; UART Rx buffer and the size of the received bytes.
			; For a packet the lengths are three, one is the target buffer size, the second is
			; the receiving buffer number of bytes and the third is the packet length. The
			; number of bytes that are going to be fetched are the smaller one of these
			; lengths. For the other two modes, binary and text, there is no predefined length
			; as in a packet, so the only lengths that count are the received bytes length and
			; the target buffer's length.
			;So, lets first test if we are in Packet mode or not
			BIC		#RSPcktCont,&UARTFlags	;Assume no packet starting if in Packet mode
			JNC		URS_TstPckt				;Carry flag cleared? => keep on
			BIS		#RSPcktCont,&UARTFlags	;else, set the Packet Continue flag
URS_TstPckt:
			MOV		&UARTRxLen,R10			;Get the number of bytes stored in Rx buffer
			CMP		R10,R6					;Is the target buffer greater or equal to the
			JHS		URS_Get					; received bytes? => OK, get them
			MOV		R6,R10					;else will only fetch as many bytes as the target
											; buffer can hold

URS_Get:	BIT		#RSBinary,&UARTFlags	;Are we in Binary Mode?
			JNZ		URS_GetBin				;Yes => Fetch stream in binary mode

			BIT		#RSPacket,&UARTFlags	;Packet mode?
			JZ		URS_GetLine				;No => Text Mode, receive up to a line of data

			CMP		#00000h,R6				;Is the target length 0? then we cannot fetch any
											; packet
			JEQ		URS_Error				;Flag the error and exit
			MOV		&UARTStreamLen,R4		;The remaining packet size to be fetched
			BIT		#RSPcktCont,&UARTFlags	;Do we have to start a new packet?
			JNZ		URS_PackLen				;No => Continue fetching the rest of the previous
											; packet
			;In a packet the first byte is its length. When there is a new packet to be
			; received, the number of bytes is the minimum of the packet length, the buffer
			; completeness and the target buffer size. R10 already contains the number of
			; bytes in the Rx Buffer - Buffer completeness. Need to fetch one byte, which is
			; the packet size, and keep the smaller number
			CALL	#UARTReceive			;Get one byte from the Rx Buffer
			JC		URS_Error				;Error? => Exit with Carry Flag set
			MOV.B	R4,0(R5)				;Store the length of the packet
			MOV		R4,&UARTStreamLen		;Store the length of the new packet
			DEC		&UARTStreamLen			;Need to read one byte less
			DEC		R10						;One less byte to fetch
			INC		R5						;Advance the target pointer to the next cell
URS_PackLen:
			CMP		R10,R4					;Packet length higher or equal to Rx Buffer bytes?
			JHS		URS_ContPack			;Yes => then keep the smaller number (Buffer size)
			MOV		R4,R10					;else, keep the packet size as it is the smaller
											; number of bytes
URS_ContPack:
			CALL	#UARTReceiveBin			;Receive a packet as binary stream
			SUB		R15,&UARTStreamLen		;Subtract the received bytes from the packet size
			JNC		URS_WTF					;More bytes read than the size of the packet? WTF!
			JNZ		URS_Error				;More bytes to read to complete the packet?
			;If the packet is complete, then we need to find if there are more packets in the
			; queue in order to schedule their reception
			DEC		&UARTPacketQ			;One packet less in the queue
			BIT		#0FFFFh,&UARTPacketQ	;Test if there is any complete packet in the queue
											; waiting
URS_Exit:	RET
URS_GetBin:
			CALL	#UARTReceiveBin			;Receive a binary stream
URS_WTF:									;Placeholder. Should never jump to WTF!!!
URS_Error:	RET

URS_GetLine:
			;Well, normally in URS_GetLine we chould CALL #UARTReceiveLine and then RET, but
			; since UARTReceiveLine follows in source code and at its end it just RETs, we can
			; skip these two lines and proceed directly to the UARTReceiveLine



;----------------------------------------
; UARTReceiveLine
; Fetches a stream of bytes from the RS232 reception buffer and copies them to a destination
; buffer. The transfer of bytes ends either when the target buffer is filled up totally, or
; when the EOL character (00 for ASCIIZ stream) appears. The terminating character is also
; copied. This is not a global function as it does not check for target buffer overflow or
; Rx buffer underflow. It expects the calling process to put in the correct maximum number of
; bytes to be copied. It should be used through UARTReceiveStream, since it calls this
; function only when in text mode. Fetching a line of data when the UART is in binary or
; packet mode does not make sense.
; INPUT         : R5 points to the target buffer
;                 R10 contains the number of bytes to be transfered
; OUTPUT        : R15 contains the number of bytes fetched.
; REGS USED     : R4, R5, R10, R11, R15
; REGS AFFECTED : R4, R5, R10, R11, R15
; STACK USAGE   : 2 = 1x Push
; VARS USED     : UARTPacketQ, UARTRxCBuf, UARTRxLen, UARTRXSIZE, UARTRxStrt
; OTHER FUNCS   : None
UARTReceiveLine:
			MOV		#00000h,R15				;Clear the number of fetched bytes
			MOV		&UARTRxStrt,R11			;Get the starting offset of the first character
URL_NextChr:CMP		#00000h,R10				;Do we have to fetch more bytes?
			JEQ		URL_End					;No => then exit

			MOV.B	UARTRxCBuf(R11),R4		;Get this byte
			MOV.B	R4,0(R5)				;Store it
			INC		R5						;Advance the target pointer to the next cell
			DEC		R10						;One character less in the reception buffer
			INC		R15						;One more characters read
			PUSH	SR						;Store the interrupts status
			DINT							;Interrupts must be off; Critical section
			NOP
			DEC		&UARTRxLen				;One character less in buffer
			INC		R11						;Advance the starting pointer to the next stored
											; character
			CMP		#UARTRXSIZE,R11			;Crossed the physical buffer's boundary?
			JLO		URL_NoRvt				;No => do not revert to the beginning
			MOV		#00000h,R11				;else, move pointer to the beginning of the buffer
URL_NoRvt:	MOV		R11,&UARTRxStrt			;Advance the starting pointer to empty the first
			POP		SR						; cell and restore interrupts state
											;End of critical section
			CMP.B	#000h,R4				;Is it a ASCIIZ terminating character?
			JNE		URL_NextChr				;No => no EOL yet, keep on
			CMP		#00000h,&UARTPacketQ	;Is there any complete line in the queue recorded?
			JEQ		URL_Exit				;No => just exit
			DEC		&UARTPacketQ			;else, exclude one line
URL_Exit:	BIT		#0FFFFh,&UARTPacketQ	;Are there any complete lines in the queue?
											; (Sets Carry Flag in case of >0)
			RET
URL_End:	BIT		#0FFFFh,&UARTRxLen		;Are there more characters in the Rx Buffer?
											; (Sets Carry Flag in case of >0)
			RET								;and return to caller


;----------------------------------------
; UARTReceiveBin
; Fetches a stream of bytes from the RS232 reception buffer and copies them to a destination
; buffer. The transfer of bytes ends when the specified number of bytes are copied. This is
; not a global function as it does not check for target buffer overflow or Rx buffer under-
; flow. It expects the calling process to put in the correct maximum number of bytes to be
; copied. It should be used through UARTReceiveStream, since it calls this function only when
; in binary mode. Using it when the UART is in text or packet mode could lead to problems.
; INPUT         : R5 points to the target buffer
;                 R10 contains the number of bytes to be transfered
; OUTPUT        : R15 contains the number of bytes fetched.
;                 Carray flag presents if there are more data received in the buffer
; REGS USED     : R4, R5, R6, R11, R15
; REGS AFFECTED : R4, R5, R6, R11, R15
; STACK USAGE   : 2 = 1x Push
; VARS USED     : UARTRxCBuf, UARTRxLen, UARTRXSIZE, UARTRxStrt
; OTHER FUNCS   : None
UARTReceiveBin:
			MOV		#00000h,R15				;Clear the number of fetched bytes
			MOV		&UARTRxStrt,R11			;Get the starting offset of the first character
URB_NextChr:CMP		#00000h,R10				;Do we have to fetch more bytes?
			JEQ		URB_End					;No => then exit

			MOV.B	UARTRxCBuf(R11),R4		;Get this byte
			MOV.B	R4,0(R5)				;Store it
			INC		R5						;Advance the target pointer to the next cell
			DEC		R10						;One character less in the reception buffer
			INC		R15						;One more characters read
			PUSH	SR						;Store the interrupts status
			DINT							;Interrupts must be off; Critical section
			NOP
			DEC		&UARTRxLen				;One character less in buffer
			INC		R11						;Advance the starting pointer to the next stored
											; character
			CMP		#UARTRXSIZE,R11			;Crossed the physical buffer's boundary?
			JLO		URB_NoRvt				;No => do not revert to the beginning
			MOV		#00000h,R11				;else, move pointer to the beginning of the buffer
URB_NoRvt:	MOV		R11,&UARTRxStrt			;Advance the starting pointer to empty the first
			POP		SR						; cell and restore interrupts state
											;End of critical section
			JMP		URB_NextChr				;Repeat for all bytes in Rx buffer
URB_End:	BIT		#0FFFFh,&UARTRxLen		;Are there more bytes in the buffer?
			RET								;Return to caller


;----------------------------------------
; Interrupt Service Routines
;========================================
;----------------------------------------
; UARTTimerISR
; When the timer is fired, the system has been idle for 10 characters time length. This means
; that if there are any characters in the reception buffer, the system needs to wake up and
; consume these characters
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : None
; VARS USED     : COMMTCCTL0, COMMTR, RSServe, UARTFlags, UARTRxLen
; OTHER FUNCS   : None
UARTTimerISR:
			CMP		#00000h,&UARTRxLen		;Are there any characters waiting in the queue?
			JEQ		TISR_Unused				;No => exit. No reason to wake up the system
TISR_WakeUp:
			BIC		#LPM4,0(SP)				;Wake up
			BIS		#RSServe,&UARTFlags		;Flag the necessity to be serviced
TISR_Unused:
			MOV		#00000h,&COMMTR			;Clear the counter
			BIC		#CCIE+CCIFG,&COMMTCCTL0	;Clear any pending interrupts and disable this
											; timer's interrupt
			RETI							;Return to interrupted process


;----------------------------------------
; UARTTxISR
; Interrupt Service Routine that handles outgoing data
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : 2 = 1x Push
; VARS USED     : COMM_IE, COMM_TXBUF, UARTTxCBuf, UARTTxLen, UARTTXSIZE, UARTTxStrt
; OTHER FUNCS   : None
UARTTxISR:
			CMP		#00000h,&UARTTxLen		;Are there any data in transmit buffer?
			JZ		RTX_Exit				;No => Exit
			PUSH	R4
			MOV		&UARTTxStrt,R4			;Get the starting pointer of transmit buffer
			MOV.B	UARTTxCBuf(R4),&COMM_TXBUF	;Send one byte from the buffer to the bus
			INC		R4						;Advance the starting pointer to the next byte
			CMP		#UARTTXSIZE,R4			;Did we reach the end of physical buffer space?
			JNE		TxSR_RvtBuf				;No => Do not revert to the beginning
			MOV		#00000h,R4				;else move the pointer to the beginning of buffer
TxSR_RvtBuf:
			MOV		R4,&UARTTxStrt			;Store the new starting pointer
			DEC		&UARTTxLen				;One character less in transmit buffer
			JNZ		TxSR_NoDis				;Reached the end?
			BIC.B	#UCTXIE,&COMM_IE		;Yes => Disable this interrupt
TxSR_NoDis:	POP		R4						;else, just exit,restoring registers used
RTX_Exit:	RETI


;-------------------------------------------
; UARTRxISR
; Interrupt Service Routine that handles incomng data
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : COMM_RXBUF, RS0A, RS0D, RSBinary, RSRxError, RSRxEol, RSServe, UARTFlags,
;                 UARTRxCBuf, UARTRxLen, UARTRXSIZE, UARTRxStrt, UARTWakeLim
; VARS USED     : 8 = 2x Push + 1x Call + 2 by called function
; OTHER FUNCS   : UARTSetupTimer
UARTRxISR:
			CMP		#UARTRXSIZE,&UARTRxLen	;Is the receive buffer full?
			JEQ		RxSRFail				;Yes => Flag the failure and exit
			PUSH	R4						;Store used registers
			PUSH	R5
			MOV		&UARTRxStrt,R4			;Get the starting pointer of the buffer
			ADD		&UARTRxLen,R4			;Add the length of stored data
			CMP		#UARTRXSIZE,R4			;Is it above the physical boundary of buffer?
			JL		RxSR_NoRvt				;No => Skip revert to its beginning
			SUB		#UARTRXSIZE,R4			;else, Subtract the length of buffer to revert it
											; to its beginning
RxSR_NoRvt:	MOV.B	&COMM_RXBUF,R5			;Get incoming byte
			BIT		#RSPacket | RSBinary,&UARTFlags	;Are we in binary or packet mode?
			JNZ		RxSRBinTim				;If yes => Do not filter incoming character; store
											; it as is
			;Text Mode - Filter EOL charcaters (CR/LF)
			CMP.B	#00Ah,R5				;Is it 0Ah (One of the line terminating values)
			JNE		RxSRNo0A				;No => OK, Check for other
			MOV.B	#000h,R5				;ASCIIZ type of line, OOh is the termination
			BIS		#RS0A | RSRxEol,&UARTFlags;Flag the character reception and the need to
											; wake up the system
			INC		&UARTPacketQ			;One more line in the buffer
			BIT		#RS0D,&UARTFlags		;Was the last character 0Dh (the other new line
											; character)
			JZ		RxSRStore				;No => OK, Keep going on storing it
			DEC		&UARTPacketQ			;else, false alarm. EOL was previously counted
			BIC		#RS0A | RS0D,&UARTFlags	;Clear both flags for character reception
			JMP		RxSR_WakeUp				;The second character is not stored. It just wakes
											; up the system
RxSRNo0A:	CMP.B	#00Dh,R5				;Is the received character 0Dh?
			JNE		RxSRNo0D				;No => OK, Store the character
			MOV.B	#000h,R5				;ASCIIZ type of line, OOh is the termination
			BIS		#RS0D | RSRxEol,&UARTFlags;Flag the reception of this character and the
											; necessity to wake up the system
			INC		&UARTPacketQ			;One more line in the buffer
			BIT		#RS0A,&UARTFlags		;Was the last character a 0A?
			JZ		RxSRStore				;No => just store the character
			BIC		#RS0A | RS0D,&UARTFlags	;else, clear the character reception flags
			DEC		&UARTPacketQ			;False alarm, This line was previously counted in
			JMP		RxSR_WakeUp				;and wake up the system. No need to store the
											; second character of the "New Line" sequence

RxSRBinTim:	BIT		#RSPacket,&UARTFlags	;Packet mode?
			JZ		RxSRBinary				;No => Use Binary Mode reception
			;Packet Mode - Decide Length and/or Wake up of the system
			CMP		#00000h,&UARTPacketLen	;Is the current packet length 0?
			JNZ		RxSR_PEndTst			;No => Have to test if this is the last packet
											; byte
			MOV		R5,&UARTPacketLen		;Store the number of bytes to receive to complete
											; the packet
			DEC		&UARTPacketLen			;Exclude length byte from the length of bytes to
											; be received to complete the packet
			JMP		RxSRNo0D				;Store and exit
RxSR_PEndTst:								;Well another byte from the packet...
			DEC		&UARTPacketLen			;Finished?
			JNZ		RxSRNo0D				;No => Just store and exit
			INC		&UARTPacketQ			;else, Another packet is in the queue
			BIS		#RSRxEol,&UARTFlags		;Flag the need to wake the system up
			JMP		RxSRNo0D				;Store and exit, waking up the system to collect
											; the received packet

			;Binary Mode
RxSRBinary:	CALL	#UARTSetupTimer			;Reset timeout counter
RxSRNo0D:	BIC		#RS0A | RS0D,&UARTFlags	;Ordinary character => No 0Ah or 0Dh
RxSRStore:	MOV.B	R5,UARTRxCBuf(R4)		;Insert the newly received value
			INC		&UARTRxLen				;Increment the length of stored data in the buffer
			BIT		#RSRxEol,&UARTFlags		;Do we need to force wake up?
			JNZ		RxSR_WakeUp				;Yes => Wake the system up
			CMP		&UARTWakeLim,&UARTRxLen	;Do we need to wake the system up?
			JL		RxSR_NoWake				;No =>  Skip waking up
RxSR_WakeUp:
			BIC		#RSRxEol,&UARTFlags		;Clear this flag if it is set
			BIS		#RSServe,&UARTFlags		;Flag the need to be served
			BIC		#LPM4,4(SP)				;Wake the system up
RxSR_NoWake:
			POP		R5						;Restore used registers
			POP		R4
			RETI
RxSRFail:	BIS		#RSRxError,&UARTFlags	;Flag the reception error
			BIC		#RS0A | RS0D,&UARTFlags	;No matter what the previous character was...
			RETI
			
			
;----------------------------------------
; UARTIDispatcher
; This is the Interrupt Service Routine called whenever there is eUSCI event. It dispatches
; to the real ISR that will serve the specific event.
; INPUT         : None
; OUTPUT        : None
; REGS USED     : None
; REGS AFFECTED : None
; STACK USAGE   : According to the ISR called
; VARS USED     : COMM_IV
; OTHER FUNCS   : UARTRxISR, UARTTxISR
UARTIDispatcher:
			ADD		&COMM_IV,PC
			RETI							;0: No interrupt
			JMP		UARTRxISR				;2: Received a byte (UCRXIFG)
			JMP		UARTTxISR				;4: Transit buffer ready (UCTXIFG)
			RETI							;6: Start bit received (UCSTTIFG)
			RETI							;8: Transmission completed (UCTXCPTIFG)


;----------------------------------------
; Interrupt Vectors
;========================================
			.sect	COMMU_Vector			;UART vector
			.short	UARTIDispatcher			;Points to the dispatcher ISR

			.sect	COMMTVECTOR0			;UART Timer vector
			.short	UARTTimerISR			;Currently to timeout service routine
