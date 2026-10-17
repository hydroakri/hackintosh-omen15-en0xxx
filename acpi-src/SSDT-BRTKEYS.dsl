// Brightness keys on HP OMEN 15 (AMD): the EC query methods only Notify the LCD device
// when VTOS() is true, i.e. when _OSI reported a Windows version. macOS reports none,
// so Fn+brightness did nothing. Rename the originals (OC ACPI patches _Q10 -> XQ10,
// _Q11 -> XQ11) and send the same Notify unconditionally. BrightnessKeys.kext then turns
// the 0x86/0x87 notifications into brightness changes.
// NOTE: SSDT-BRTKEYS.aml was assembled by hand (no iasl on the Mac); this .dsl is the
// intended source - recompile it with iasl to cross-check.
DefinitionBlock ("", "SSDT", 2, "CORP", "BRTKEYS", 0x00000001)
{
    External (_SB_.PCI0.GP17.VGA_.LCD_, DeviceObj)
    Scope (\_SB.PCI0.SBRG.EC0)
    {
        Method (_Q10, 0, Serialized)  // Brightness down
        {
            Notify (\_SB.PCI0.GP17.VGA.LCD, 0x87)
        }

        Method (_Q11, 0, Serialized)  // Brightness up
        {
            Notify (\_SB.PCI0.GP17.VGA.LCD, 0x86)
        }
    }
}
