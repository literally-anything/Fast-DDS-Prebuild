# Fast-DDS-Prebuild
## Prebuilt Eprosima [Fast-DDS](https://github.com/eProsima/Fast-DDS) v3 (formerly FastRTPS) library for Apple platforms.


### Supported platforms and architectures
| Platform                        |  Architectures     |
|---------------------------------|--------------------|
| macOS                           | x86_64 arm64       |
| iOS                             | arm64              |
| iOS Simulator                   | x86_64 arm64       |
| Mac Catalyst (Not Working)      | x86_64 arm64       |
| xrOS                            | arm64              |
| xrOS Simulator                  | arm64              |

### Usage

Add line to you Package.swift dependencies:

```
.package(url: "https://github.com/literally-anything/Fast-DDS-Prebuild.git", from: "3.0.1")
```

### Build It Yourself
To build version 3.0.1 from sources, run:
```
bash build.bash v3.0.1
```

#### Requirements 

- Xcode Command Line Tools
- cmake 3.30
