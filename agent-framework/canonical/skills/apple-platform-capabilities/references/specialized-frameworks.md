# Specialized capability selection

Add a capability-specific method only for approved product work. Record framework/OS/device,
entitlements, sensitive data, permission denial and real runtime prerequisites before building.

| Actual need | Primary framework route | Important applicability |
| --- | --- | --- |
| Camera/audio/video/photos | AVFoundation / Photos | Permissions, interruptions, media rights, memory |
| Location/maps | Core Location / MapKit | Accuracy, foreground/background consent, energy |
| Bluetooth/accessories | Core Bluetooth | Device availability, disconnect/reconnect, pairing limits |
| Health | HealthKit | Sensitive data, capabilities and denied/partial authorization |
| Home automation | HomeKit | Actual home/accessory access and authorization |
| Automotive | CarPlay | Supported category, entitlement and vehicle testing |
| AR | ARKit | Supported hardware, camera consent and tracking failure |
| On-device ML/AI | Core ML / Foundation Models | Actual OS/device/model availability, latency and data handling |

Consult current [Apple documentation](https://developer.apple.com/documentation/) for the selected
framework; this table is a routing aid, not a claim that every capability is supported on iOS 17.
When a dedicated specialist is needed, choose it by authority/output boundaries rather than
creating a role for every SDK. Backend/compliance work needs its own scoped expertise and evidence.
