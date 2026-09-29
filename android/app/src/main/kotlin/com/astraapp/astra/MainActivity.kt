package com.astraapp.astra

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity rather than plain FlutterActivity: just_audio_background
// binds the notification-center/lock-screen media session through it, and a
// plain FlutterActivity never receives the button presses it posts.
class MainActivity : AudioServiceActivity()
