# Insecure deserialization

[← Foothold quick reference](../02-foothold.md)

Identify the serialized value, parser, and reachable class/gadget path.

| Stack | Clue to check |
| --- | --- |
| Java | Base64 beginning `rO0AB` or bytes beginning `ac ed 00 05`; identify the classes on the server. |
| .NET | `__VIEWSTATE`, BinaryFormatter, LosFormatter, or Json.NET handling; check signing and the application's `machineKey` settings. |
| PHP | `unserialize()` on input you control, with reachable `__wakeup()` or `__destruct()` methods. |
| Python | `pickle.loads()` on input you control. |

Compare baseline with one harmless change; parser errors alone do not prove execution.
