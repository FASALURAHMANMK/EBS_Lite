# POS hardware + print smoke checklist (Windows + Android)

Date: 2026-03-03

Goal: Validate the practical “store-floor” behaviors for printing/scanning/drawer, including reprint/share.

## Pre-reqs
- Configure at least one device printer:
  - Flutter: `Printer Settings (Device)` → `flutter_app/lib/features/dashboard/presentation/pages/printer_settings_page.dart`
  - For thermal printers, optionally enable `Kick cash drawer` (ESC/POS drawer pulse).

## Windows (Desktop)
1. **Barcode scan (keyboard wedge)**
   - Focus POS search field (`New Sale` screen).
   - Scan a barcode and confirm it searches/adds the correct product.
2. **Thermal receipt print (80/58mm)**
   - Complete a sale from POS and choose `Print`.
   - Confirm receipt prints with correct totals (subtotal/tax/discount/total).
3. **Cash drawer kick (if enabled)**
   - With `Kick cash drawer` enabled on the printer config, print a sale.
   - Confirm the drawer opens.
4. **Reprint**
   - Go to Sales History → open a sale → Print.
   - Confirm it prints the same sale correctly.
5. **Share PDF**
   - From Sale Detail or payment success dialog → `Share Invoice`.
   - Confirm a PDF is generated and share flow opens.

## Android
1. **Barcode scan (keyboard wedge)**
   - If using a paired scanner, repeat the Windows scan test.
2. **Bluetooth thermal print**
   - Configure Bluetooth thermal printer and print a sale.
3. **Drawer kick**
   - If the printer supports drawer pulse, enable `Kick cash drawer` and verify open.
4. **Share PDF**
   - `Share Invoice` and confirm Android share sheet opens.

## Known limitations / notes
- Camera barcode scanning is not implemented unless a separate scanner/camera flow exists in your build; primary path is keyboard-wedge input.
- Loyalty points earned/redeemed are processed server-side, but receipts may not display points yet (see `POS_CHECKLIST_2026_03_03.md`).

