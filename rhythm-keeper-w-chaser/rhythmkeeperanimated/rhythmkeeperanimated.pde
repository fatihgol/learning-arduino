/*
  Rhythm Keeper with animation implementation
  
  Uses a push button to detect the beat through the users tapping rhythm.
  The code records the tap intervals and calculates the BPM, flashing an LED to the beat.
  The beat timing controls the animation of a 8x LED matrix managed through a basic Shift Register.
  
  It uses two libraries:
  1. http://github.com/d2kagw/arduino-tap-library/
  2. http://github.com/d2kagw/arduino-rhythm-library/
  
  The Rhythm Keeper, sans animation/LED matrix can be found here
  http://learning-arduino.tumblr.com/post/2563968841/arduino-rhythm-keeper
  
  Details on the circuit can be found here:
  http://github.com/d2kagw/learning-arduino/tree/master/rhythm-keeper-w-chaser
  
  Created 3/1/11 by Aaron Wallis
*/

#include <Tap.h>     // http://github.com/d2kagw/arduino-tap-library/
#include <Rhythm.h>  // http://github.com/d2kagw/arduino-rhythm-library/

// the animation patterns are saved in the patterns.h file
// in an attempt to keep this file clean
#include "patterns.h"



// ----------------------------------
// Configuration Vars
//

// all the pin declerations - change if necessary
#define       PIN_BUTTON  10
#define     PIN_LED_BEAT  9
#define   PIN_LED_STATUS  8

#define  PIN_SERIAL_DATA  2
#define PIN_SERIAL_LATCH  3
#define PIN_SERIAL_CLOCK  4

// By default the app will require ten 'taps'
// but you can change this value to a smaller number if you like
// the larger the number, the greater the accuracy, but the longer
// the learning process
int requiredTaps = 6;



// ----------------------------------
// Internal Vars
//

// pattern cycle management
int pattern_index = 0;
int pattern_count = (sizeof(patterns) - 1) / 2;

// Tap and Rhythm library
Tap tapper(PIN_BUTTON);
Rhythm beater;

// learning state management
boolean _isListening = false;
boolean _isFirst     = false;
int _tapCount        = 0;

// animation management
unsigned int _clock          = 0;
unsigned int _timingClock    = 0;
unsigned int _requiredTiming = 0;



// ----------------------------------
// Setup
//
void setup () {
  // Start the logger
  Serial.begin(9600);
  
  // setup the LED pins
  pinMode(   PIN_LED_STATUS, OUTPUT);
  pinMode(     PIN_LED_BEAT, OUTPUT);
  pinMode(  PIN_SERIAL_DATA, OUTPUT);
  pinMode( PIN_SERIAL_CLOCK, OUTPUT);
  pinMode( PIN_SERIAL_LATCH, OUTPUT);
  
  // reset the animation & shift register
  resetAnimation();
};



// ----------------------------------
// Main Loop
//
void loop() {
  // control the animation timing based on the stored beat
  // if we're not listening and we've got a beat timing...
  if (!_isListening && beater.currentTiming != 0) {
    
    // look for whole beats
    // just for the beat status light
    if (_clock == beater.currentTiming) {
      Serial.println("doof");
      digitalWrite(PIN_LED_BEAT, digitalRead(PIN_LED_BEAT) != HIGH);
      _clock = 0;
    }
    
    // if the clock is at the required timing
    if (_timingClock == _requiredTiming) {
      // move to the next stage of the LED Matrix animation
      digitalWrite(PIN_SERIAL_LATCH, LOW);
      shiftOut(PIN_SERIAL_DATA, PIN_SERIAL_CLOCK, MSBFIRST, patterns[pattern_index*2]);
      digitalWrite(PIN_SERIAL_LATCH, HIGH);
      
      // store the timing for the next cycle
      _requiredTiming = ((beater.currentTiming * patterns[(pattern_index*2)+1]) / WHOLE_BEAT);
      
      // increment the pattern index
      pattern_index ++;
      
      // loop if necessary
      if (pattern_index > pattern_count) pattern_index = 0;
      
      // reset the clock
      _timingClock = 0;
    }
    
    // increment the clock
    _timingClock ++;
    _clock ++;
  } else {
    digitalWrite(PIN_LED_BEAT, LOW);
  }
  
  // call the beat manage method
  // this guy controls the detection of ze rhythm
  beatManage();
  
  // a delay is required for the timing to work correctly.
  // not entirely sure why this is the case,
  // maybe someone smarter than I could explain?
  delay(1);
}



// --------------------------------------------------------------
// Reset Animation, called when the user is changing the timing
//
void resetAnimation() {
  // reset the shift register back to null
  digitalWrite(PIN_SERIAL_LATCH, LOW);
  shiftOut(PIN_SERIAL_DATA, PIN_SERIAL_CLOCK, MSBFIRST, B00000000);
  digitalWrite(PIN_SERIAL_LATCH, HIGH);
  
  // all indexes back to zero
  pattern_index   = 0;
  _timingClock    = 0;
  _clock          = 0;
  _requiredTiming = 0;
}



// ---------------------------------------
// Where all the beat management occurs
//
void beatManage() {
  // if the button is down...
  if (tapper.isHit()) {
    // and we're not currently counting taps
    if (_isListening == false) {
      // start counting taps
      _isListening = _isFirst = true;
      _tapCount = 0;
      
      // call the reset method
      resetAnimation();
      
      // turn on the status light so the user knows we're expecting input
      digitalWrite(PIN_LED_STATUS, HIGH);
      Serial.println("Listening");
    
    // if we are already counting taps
    } else {
      
      // and this is the first tap
      if (_isFirst) {
        // reset the rhythm library
        beater.reset();
        _isFirst = false;
        
        digitalWrite(PIN_LED_BEAT, HIGH);
        Serial.println("first tap");
      
      // if it's not the first tap
      } else {
        
        // record the tap in the library
        beater.tap();
        
        digitalWrite(PIN_LED_BEAT, HIGH);
        Serial.println("tap");
      }
      
      // increment out counter
      _tapCount ++;
    }
  };
  
  // have we reached our tap count?
  if (_tapCount > requiredTaps && _isListening) {
    // stop listening and turn off the status LED
    _isListening = false;
    digitalWrite(PIN_LED_STATUS, LOW);
  }
  
  // if we're listening, hit the loop
  if (_isListening) beater.loop();
};


