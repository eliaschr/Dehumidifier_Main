# Dehumidifier_Main
A Juro Pro Oxygen 16L Dehumidifier, totally hacked!!!

## The Story Behind
I own a Juro Pro Oxygen 16L Dehumidifier. After 2 years of usage it started mulfunctioning,
so, as an electronic engineer I had to find out what the problem was.
The electronics part is split in two sections, one is the main board containing a
microcontroller that controls the compressor, the fan and the anionizer, and a one which is
the control panel containing the 7 LEDs, 2 7-segment displays and 5 pushbuttons and of course
a microcontroller to handle these components. The two sections communicate to eachother using
serial communication (UART) at 9600 bps, so the panel can send the keypresses to the main
board and the main board can send the visual representations of the leds/displays.

After two years of usage, the front panel stopped working so the system could not be turned
on!. After communicating to the service department of my area, asking to get a new panel pcb,
physical presence, e-mails and phone calls to the central offices, STILL waiting for the new
panel to arrive after three months of waiting, I finaly took the decision to hack it and do my
job!

There was the possibility to spy on communication between the two units on a working machine
and reverse engineer it in order to make a new panel simulating the older one, but it is more
fun to start a totally new project. It would be another open source project to help others
understand the way these things work and finaly get my machine working again.

Sorry Juro Pro, but I'll never be your client again.

## Some Information About The Machine
The information presented here are what anyone with fundamental knowledge of electronics could
find out, by just unscrewing the machine. There will be no reverse engineering of any
communication ar any trial of cracking the microcotnrollers to reveal their code. Just what
anyone could see or measure using simple test and measurement equipment.

The contained electronics are kind of... cheap things, doing their job though (in normal
conditions :)). This way they keep the price of the dehumidifier low, providing the necessary
functionality. The quality of the electronic parts is not something special, but as I said
they do their job.

On the main board there is a small power supply, based on OB2226 power controller, the main
microcontroller, of unknown provider and identity, some electronics to bias the temperature
and humidity sensors and some relays to control the compressor, fun and anionizer. The power
supply powers the system with 12V (for relays and the buzzer) and 5V for the rest. There is a
NTC thermistor to measure the temperature of the cooler. In front of it there is a small box
containing the humidity sensor and another NTC to measure the ambient temperature. The
humidity sensor is pure analog component, so there is the need to also measure its temperature
in order to perform calibration. The readings of humidity sensors is highly dependent of the
temperature so there is always the need to normalize the humidity reading according to the
temperature of the sensor.

On the front panel PCB there is only one microcontroller (SH69P24M of Sino Wealth) driving the
leds/displays and reading the pushbuttons' keypresses, that communicates to the main board
 through UART.

## The Goal Of The Project
Our goal is to replace the electronics (mostly microcontrollers and sensors) and make a _new_
working machine with the ability to keep a log of the environmental parameters and present
them on a small LCD display. But first things first. Lets make it a working machine with the
resources provided by the maker company (Leds/Displays/Pushbuttons, Compressor, Fan, Anionizer
e.t.c.) and then add-on the rest of the needs.
