# Decentralized Instant Message (Dart Demo)

[![License](https://img.shields.io/github/license/dimpart/demo-dart)](https://github.com/dimpart/demo-dart/blob/master/LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/dimpart/demo-dart/pulls)
[![Platform](https://img.shields.io/badge/Platform-Dart%203-brightgreen.svg)](https://github.com/dimpart/demo-dart/wiki)
[![Issues](https://img.shields.io/github/issues/dimpart/demo-dart)](https://github.com/dimpart/demo-dart/issues)
[![Repo Size](https://img.shields.io/github/repo-size/dimpart/demo-dart)](https://github.com/dimpart/demo-dart/archive/refs/heads/main.zip)
[![Tags](https://img.shields.io/github/tag/dimpart/demo-dart)](https://github.com/dimpart/demo-dart/tags)
[![Version](https://img.shields.io/pub/v/dim_client)](https://pub.dev/packages/dim_client)

[![Watchers](https://img.shields.io/github/watchers/dimpart/demo-dart)](https://github.com/dimpart/demo-dart/watchers)
[![Forks](https://img.shields.io/github/forks/dimpart/demo-dart)](https://github.com/dimpart/demo-dart/forks)
[![Stars](https://img.shields.io/github/stars/dimpart/demo-dart)](https://github.com/dimpart/demo-dart/stargazers)
[![Followers](https://img.shields.io/github/followers/dimpart)](https://github.com/orgs/dimpart/followers)

## Dependencies

* Latest Versions

| Name | Version | Description |
|------|---------|-------------|
| [Ming Ke Ming (名可名)](https://github.com/dimchat/mkm-dart) | [![Version](https://img.shields.io/pub/v/mkm)](https://pub.dev/packages/mkm) | Decentralized User Identity Authentication |
| [Dao Ke Dao (道可道)](https://github.com/dimchat/dkd-dart) | [![Version](https://img.shields.io/pub/v/dkd)](https://pub.dev/packages/dkd) | Universal Message Module |
| [DIMP (去中心化通讯协议)](https://github.com/dimchat/core-dart) | [![Version](https://img.shields.io/pub/v/dimp)](https://pub.dev/packages/dimp) | Decentralized Instant Messaging Protocol |
| [DIM SDK](https://github.com/dimchat/sdk-dart) | [![Version](https://img.shields.io/pub/v/dimsdk)](https://pub.dev/packages/dimsdk) | Software Development Kit |
| [DIM Plugins](https://github.com/dimchat/plugins-dart) | [![Version](https://img.shields.io/pub/v/dim_plugins)](https://pub.dev/packages/dim_plugins) | Cryptography & Account Plugins |
| [Star Gate](https://github.com/moky/StarGate) | [![Version](https://img.shields.io/pub/v/stargate)](https://pub.dev/packages/stargate) | Network Connection Module (WebSocket) |
| [LNC](https://github.com/dimpart/demo-dart) | [![Version](https://img.shields.io/pub/v/lnc)](https://pub.dev/packages/lnc) | Log, Notification & Cache |

* pubspec.yaml

```
environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  object_key:  ^1.1.1
  lnc:         ^1.2.2
#  startrek:    ^1.2.0
  stargate:    ^1.2.0
  
#  mkm:         ^2.3.6
#  dkd:         ^2.3.6
#  dimp:        ^2.3.6
  dimsdk:      ^2.3.6
  dim_plugins: ^2.3.6
```

## FIXME

LoadException:

```
../../../../../.pub-cache/hosted/pub.dev/asn1lib-1.6.5/lib/src/asn1octetstring.dart:30:26: Error: A value of type 'List<int>' can't be assigned to a variable of type 'Uint8List'.
 - 'List' is from 'dart:core'.
 - 'Uint8List' is from 'dart:typed_data'.
      this.octets = utf8.encode(octets);
                         ^
```

* **file**: asn1lib-1.6.5/lib/src/asn1octetstring.dart
* **line**: 29

```dart
  ASN1OctetString(dynamic octets, {super.tag = OCTET_STRING_TYPE}) {
    if (octets is String) {
      // We now default to utf8 encoding
      this.octets = Uint8List.fromList(octets.codeUnits);
      // this.octets = utf8.encode(octets);
    } else if (octets is Uint8List) {
      this.octets = octets;
    } else if (octets is List<int>) {
      this.octets = Uint8List.fromList(octets);
    } else {
      throw ArgumentError(
        'Parameters octets should be either of type String or List<int>.',
      );
    }
  }
```

Copyright &copy; 2023-2026 Albert Moky
[![Followers](https://img.shields.io/github/followers/moky)](https://github.com/moky?tab=followers)
