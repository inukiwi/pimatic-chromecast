pimatic-chromecast
=======================
[![npm version](https://badge.fury.io/js/pimatic-chromecast.svg)](https://badge.fury.io/js/pimatic-chromecast)

Access your Google Cast devices in pimatic

## Features
- Discover Google Cast compatible devices and groups in your network
- Retrieve media status from Chromecast (playstate, volume, artist, title)
- Control media (play, pause, stop, skip, previous)
- Control volume using rules
- Cast video/audio using rules
- Cast speech using text-to-speech

## Rules usage
Casting media:
```
cast {{ url }} to {{ device }}
```
Casting text (to speech):
```
cast {{ text }} in language {{ language }} to {{ device }}
```

## Supported languages for text-to-speech
Use the language codes that are available in [node-gtts](https://github.com/thiennq/node-gtts/blob/master/index.js#L10), for example 'en', 'de', or 'nl'.

## Requirements
This plugins uses multicast DNS service discovery using the mdns library, which has the following requirement:
On Linux and other systems using the avahi daemon the avahi dns_sd compat library and its header files are required.  On debianesque systems the package name is `libavahi-compat-libdnssd-dev`, on fedoraesque systems the package is `avahi-compat-libdns_sd-devel`.  On other platforms Apple's [mDNSResponder](http://opensource.apple.com/tarballs/mDNSResponder/) is recommended. Care should be taken not to install more than one mDNS stack on a system.

On Windows you are going to need Apples "Bonjour SDK for Windows". You can download it either from Apple (registration required) or various unofficial sources. Take your pick. After installing the SDK restart your computer and make sure the `BONJOUR_SDK_HOME` environment variable is set. You'll also need a compiler. Microsoft Visual Studio Express will do. On Windows node >=0.7.9 is required.
