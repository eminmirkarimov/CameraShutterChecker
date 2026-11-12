## Camera Shutter Checker v2.4.1 — Windows

An offline Windows utility that inspects image and RAW metadata for recognized camera shutter counters.

### Included
- Built-in EXIF/TIFF/MakerNotes parser — ExifTool is not required.
- Local processing; photos are not uploaded to a server.
- Sony MakerNotes decoding for selected models. Practical testing has so far been carried out on a Sony camera.
- Partial, model-specific Canon CR2/CR3 parsing.
- Nikon, Fujifilm and Pentax/Ricoh counter-field implementations, with hardware validation still pending.

### Camera support notes
- **Sony:** the first practically tested manufacturer. Model-specific layouts are implemented; not every Sony model has been individually validated.
- **Canon CR2/CR3:** partial support only. Selected EOS R CR3 layouts and selected EOS-1D/1Ds CR2 FileInfo layouts are handled. Many Canon cameras do not store a lifetime shutter count in a photo.
- **Nikon / Fujifilm / Pentax / Ricoh:** code paths are implemented, but model-by-model physical testing is still required.
- **Panasonic / OM System-Olympus / Leica:** no verified manufacturer-specific counter decoder is currently claimed.

### Important
A missing counter does not mean zero actuations. `ImageCount`, file numbering, total exposures and mechanical shutter actuations are not necessarily the same value. Use original files copied directly from the memory card.

### Download
Download `CameraShutterChecker.exe` from the **Assets** section below.

Created and maintained by **Emin Mirkarimov**.  
Copyright (c) 2026 Emin Mirkarimov. All rights reserved.
