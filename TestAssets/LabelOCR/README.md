# Label OCR Test Images

Copy these images to the Photos app, then use **Add item > Choose photo**. Every scan should open **Review label** before changing the item draft.

| File | Coverage | Expected suggestions |
| --- | --- | --- |
| `01-hvac-filter-en.png` | Clear, straight English label | Brand `Filtrete`; model `MPR-1000`; size `16 x 25 x 1 in`; category `HVAC filters` |
| `02-water-filter-en-angle.png` | Angled English label | Brand `AquaPure`; model `AP-4396508`; size `10.2 x 2.4 in`; category `Water filters` |
| `03-led-bulb-en-warm.png` | Warm light and mixed specifications | Brand `LumaHome`; model `LH-A19-9W`; size `A19 / 9W / 800 lm`; category `Light bulbs` |
| `04-water-filter-zh.png` | Simplified Chinese label | Name `净水器滤芯`; brand `清泉`; model `QY-RO-05`; size `10英寸`; category `Water filters` |
| `05-vacuum-filter-unlabeled.png` | No Brand/Model/Size prefixes | Brand `CleanNest`; model `CN-HF220`; size `9.5 x 8.2 x 1.1 in`; category `Appliances` |

Notes:

- OCR may read lowercase `lm` as `Im` in the warm-light image. This is intentional: the review screen must allow correction before applying.
- **Apply details** only fills the suggested name when the current item name is empty; it never overwrites a name the user already entered.
- **Enter manually** closes the review and focuses the model-number field.
