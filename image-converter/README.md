# Card Image Converter

Click the drop-style area to choose an image, then it converts immediately to
WebP, PNG, JPG or AVIF. The left and right arrows change the format.

Noctalia does not expose OS file drops to plugin desktop widgets, so the area
opens a native file picker instead. The result is saved next to the input; if
that folder is not writable, it goes to **~/Pictures/Converted**.

Requires Noctalia 5.4 or newer, a file picker (`zenity`, `kdialog` or `yad`), and
ImageMagick (`magick` or `convert`) or FFmpeg.
