# Insecure deserialization

[← Foothold quick reference](../02-foothold.md)

Look for a user-controlled value that the server turns back into an object. A format clue is only a lead; confirm the parser and the reachable code path before choosing a payload.

| Stack | Clue to check |
| --- | --- |
| Java | Base64 beginning `rO0AB` or bytes beginning `ac ed 00 05`; identify the classes on the server. |
| .NET | `__VIEWSTATE`, BinaryFormatter, LosFormatter, or Json.NET handling; check signing and the application's `machineKey` settings. |
| PHP | `unserialize()` on input you control, with reachable `__wakeup()` or `__destruct()` methods. |
| Python | `pickle.loads()` on input you control. |

Compare a normal serialized value with one harmless change. An error or format match is not proof of code execution.
