.equ ADDR_PUSHBUTTONS, 0xFF200050 # Address Pushbuttons
.equ ADDR_JP1, 0xFF200060   # Address GPIO JP1
.equ ADDR_JP1_IRQ, 0x0800      # IRQ line for GPIO JP1 (IRQ11)
.equ TIMER, 0xFF202000 # Address TIMER
.equ PERIOD, 1000000 # time period for polling

.text

.global main

main:
start:
        call InitTimer
        call InitMotors
        movia  r8, ADDR_JP1_IRQ    # enable interrupt for GPIO JP1 (IRQ11) 
        wrctl  ctl3, r8
        movia  r8, 1
        wrctl  ctl0, r8            # enable global interrupts
LOOP:
        br LOOP

InitTimer:
        movia r8,TIMER
        movui r9,%lo(PERIOD)
        stwio r9,8(r8) # low 16bits
        movui r9,%hi(PERIOD)
        stwio r9,12(r8) # high 16bits
        stwio r0,0(r8) # clear the timer
        ret

InitMotors:
        movia r8, ADDR_JP1
        movia r9, 0x07f557ff       # set direction for motors to all output 
        stwio r9, 4(r8)
        # load sensor0 threshold value 5 and enable sensor0
        movia  r9,  0xfabffbff       # set motors off enable threshold load sensor 0
        stwio  r9,  0(r8)            # store value into threshold register
        # load sensor1 threshold value 5 and enable sensor1
        movia  r9,  0xfabfefff       # set motors off enable threshold load sensor 1
        stwio  r9,  0(r8)            # store value into threshold register
        # load sensor2 threshold value 5 and enable sensor2
        movia  r9,  0xfabfbfff       # set motors off enable threshold load sensor 2
        stwio  r9,  0(r8)            # store value into threshold register
        # disable threshold register and enable state mode
        movia  r9,  0xfadffff0      # keep threshold value same in case update occurs before state mode is enabled, and enable motor 0 and motor 1 to be forward
        stwio  r9,  0(r8)
        # enable interrupts
        movia  r9, 0x08000000       # enable interrupts on sensor 0
        stwio  r9, 8(r8)
        ret

.section .exceptions, "ax"
IHANDLER:
        # check to see if sensor0 interrupt happened    
        rdctl et, ctl4
        andi et,et,0x0800 # check if interrupt pending from IRQ11 (ctl4:bit1)
        beq et,r0,exit # if not sensor0, exit the ISR

ChangeDir:
        movia r10, ADDR_JP1
        ldwio r11, 12(r10)
        movia r12, 0x08000000	# check if interrupt caused by sensor 0 
        and r11, r11, r12
        srli r11, r11, 0x1b
        bne r11, r0, MOTOR_TURN_RIGHT
		br exit

MOTOR_TURN_RIGHT:
		movia 	 r11, 0xfffffc00
		ldwio 	 r12, 0(r10)
		and		 r11, r11, r12		  # get mask for all the bits except for the motor (first 22 bits)
        movia	 et, 0x000003f3       # motor1 enabled (bit0=0), direction set to forward (bit1=0) 
		or 		 et, et, r11		  # preserve the original setting and only turn on motor 1
        stwio	 et, 0(r10)
        call StartTimer # polling for PERIOD amount of time
        br FINISH_TURN

FINISH_TURN:
		movia	 r12, 0x000003ff
		or 		 et, r11, r12		# motor0 and motor1 disabled (bit0=1), direction set to backward (bit1=1) 
        stwio	 et, 0(r10)
		stwio	 et, 12(r10)		# Write to Edge Capture Register (which clears it)

exit:
        subi ea,ea,4 # adjust return address
        eret

StartTimer:
        movia r8,TIMER
        movui r9,0x4 # start timer, not continued
        stwio r9,4(r8)

Poll:   
        ldwio r9,0(r8)
        andi r9,r9,0x1 # check if timer has timed out
        beq r9,r0,Poll # loop and check again
        stwio r0,0(r8) # clear the timer
        ret # PERIOD seconds has passed