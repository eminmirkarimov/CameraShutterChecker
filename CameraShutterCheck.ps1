# Camera Shutter Checker 2.4.1
# Автор проекта и разработчик: Emin Mirkarimov
# Copyright (c) 2026 Emin Mirkarimov. All rights reserved.
# Собственный EXIF/TIFF/MakerNotes parser. ExifTool и другие внешние программы НЕ используются.
# Требуется только Windows PowerShell 5.1 или PowerShell 7 на Windows.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$source = @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Text;

namespace CameraShutterCheckNative
{
    public sealed class IfdEntry
    {
        public ushort Tag;
        public ushort Type;
        public uint Count;
        public byte[] Data;
        public bool Little;
        public int DataOffset;
    }

    public sealed class PhotoInfo
    {
        public string Make = "";
        public string Model = "";
        public string Date = "";
        public byte[] MakerNote = null;
        public byte[] SourceBytes = null;
        public int TiffBase = 0;
        public int MakerNoteOffset = -1;
        public bool MakerNoteLittle = true;
        public byte[] CanonCameraInfo = null;
        public byte[] CanonFileInfo = null;
        public bool IsCr3 = false;
        public bool Little = true;
        public List<string> Counters = new List<string>();
        public string Status = "";
    }

    public static class Parser
    {
        static ushort U16(byte[] b, int p, bool le)
        {
            if (b == null || p < 0 || p + 2 > b.Length) return 0;
            return le ? (ushort)(b[p] | (b[p + 1] << 8)) : (ushort)((b[p] << 8) | b[p + 1]);
        }
        static uint U32(byte[] b, int p, bool le)
        {
            if (b == null || p < 0 || p + 4 > b.Length) return 0;
            if (le) return ((uint)b[p]) | ((uint)b[p + 1] << 8) | ((uint)b[p + 2] << 16) | ((uint)b[p + 3] << 24);
            return ((uint)b[p] << 24) | ((uint)b[p + 1] << 16) | ((uint)b[p + 2] << 8) | ((uint)b[p + 3]);
        }
        static uint U32BE(byte[] b, int p) { return U32(b, p, false); }
        static string Ascii(byte[] b)
        {
            if (b == null || b.Length == 0) return "";
            int n = Array.IndexOf(b, (byte)0);
            if (n < 0) n = b.Length;
            return Encoding.ASCII.GetString(b, 0, n).Trim();
        }
        static int TypeSize(ushort t)
        {
            switch (t)
            {
                case 1: case 2: case 6: case 7: return 1;
                case 3: case 8: return 2;
                case 4: case 9: case 11: return 4;
                case 5: case 10: case 12: return 8;
                default: return 0;
            }
        }
        static byte[] Slice(byte[] src, int off, int len)
        {
            if (src == null || off < 0 || len < 0 || off > src.Length || len > src.Length - off) return new byte[0];
            byte[] r = new byte[len];
            Buffer.BlockCopy(src, off, r, 0, len);
            return r;
        }
        static bool IsTiff(byte[] b, int p)
        {
            if (b == null || p < 0 || p + 8 > b.Length) return false;
            bool le = b[p] == 0x49 && b[p + 1] == 0x49;
            bool be = b[p] == 0x4d && b[p + 1] == 0x4d;
            if (!le && !be) return false;
            return U16(b, p + 2, le) == 42;
        }
        static List<IfdEntry> ReadIfd(byte[] b, int valueBase, int ifdAbsolute, bool le)
        {
            List<IfdEntry> list = new List<IfdEntry>();
            if (b == null || ifdAbsolute < 0 || ifdAbsolute + 2 > b.Length) return list;
            ushort n = U16(b, ifdAbsolute, le);
            if (n == 0 || n > 1024 || ifdAbsolute + 2L + n * 12L > b.Length) return list;
            for (int i = 0; i < n; i++)
            {
                int p = ifdAbsolute + 2 + i * 12;
                ushort tag = U16(b, p, le);
                ushort type = U16(b, p + 2, le);
                uint count = U32(b, p + 4, le);
                int sz = TypeSize(type);
                if (sz == 0 || count > 1000000) continue;
                long byteCount = (long)sz * count;
                if (byteCount < 0 || byteCount > 16 * 1024 * 1024) continue;
                int dataOff;
                if (byteCount <= 4) dataOff = p + 8;
                else
                {
                    uint rel = U32(b, p + 8, le);
                    long abs = (long)valueBase + rel;
                    if (abs < 0 || abs > b.Length || byteCount > b.Length - abs) continue;
                    dataOff = (int)abs;
                }
                if (dataOff < 0 || dataOff > b.Length || byteCount > b.Length - dataOff) continue;
                list.Add(new IfdEntry { Tag = tag, Type = type, Count = count, Data = Slice(b, dataOff, (int)byteCount), Little = le, DataOffset = dataOff });
            }
            return list;
        }
        static IfdEntry Find(List<IfdEntry> es, ushort tag)
        {
            if (es == null) return null;
            foreach (IfdEntry e in es) if (e.Tag == tag) return e;
            return null;
        }
        static uint EntryUInt(IfdEntry e)
        {
            if (e == null || e.Data == null || e.Data.Length == 0) return 0;
            if (e.Type == 3 && e.Data.Length >= 2) return U16(e.Data, 0, e.Little);
            if ((e.Type == 4 || e.Type == 9) && e.Data.Length >= 4) return U32(e.Data, 0, e.Little);
            if (e.Type == 1 && e.Data.Length >= 1) return e.Data[0];
            if (e.Data.Length >= 4) return U32(e.Data, 0, e.Little);
            if (e.Data.Length >= 2) return U16(e.Data, 0, e.Little);
            return e.Data[0];
        }
        static void ParseIfdTree(byte[] b, int tiffBase, uint relIfd, bool le, PhotoInfo info, HashSet<int> visited, int depth)
        {
            if (depth > 5) return;
            long absLong = (long)tiffBase + relIfd;
            if (absLong < 0 || absLong > b.Length - 2) return;
            int abs = (int)absLong;
            if (!visited.Add(abs)) return;
            List<IfdEntry> es = ReadIfd(b, tiffBase, abs, le);
            if (es.Count == 0) return;
            foreach (IfdEntry e in es)
            {
                if (e.Tag == 0x010F && info.Make.Length == 0) info.Make = Ascii(e.Data);
                else if (e.Tag == 0x0110 && info.Model.Length == 0) info.Model = Ascii(e.Data);
                else if (e.Tag == 0x9003 && info.Date.Length == 0) info.Date = Ascii(e.Data);
                else if (e.Tag == 0x927C && e.Data != null && e.Data.Length > 0)
                {
                    info.MakerNote = e.Data;
                    info.SourceBytes = b;
                    info.TiffBase = tiffBase;
                    info.MakerNoteOffset = e.DataOffset;
                    info.MakerNoteLittle = le;
                }
            }
            IfdEntry exif = Find(es, 0x8769);
            IfdEntry gps = Find(es, 0x8825);
            IfdEntry sub = Find(es, 0x014A);
            if (exif != null) ParseIfdTree(b, tiffBase, EntryUInt(exif), le, info, visited, depth + 1);
            if (gps != null) ParseIfdTree(b, tiffBase, EntryUInt(gps), le, info, visited, depth + 1);
            if (sub != null && sub.Data.Length >= 4) ParseIfdTree(b, tiffBase, EntryUInt(sub), le, info, visited, depth + 1);
        }
        static bool ParseTiff(byte[] b, int baseOff, PhotoInfo info)
        {
            if (!IsTiff(b, baseOff)) return false;
            bool le = b[baseOff] == 0x49;
            uint first = U32(b, baseOff + 4, le);
            if (first == 0 || (long)baseOff + first > b.Length - 2) return false;
            info.Little = le;
            ParseIfdTree(b, baseOff, first, le, info, new HashSet<int>(), 0);
            return true;
        }
        static void ParseJpegSegments(byte[] b, PhotoInfo info)
        {
            if (b == null || b.Length < 4 || b[0] != 0xFF || b[1] != 0xD8) return;
            int p = 2;
            while (p + 4 <= b.Length)
            {
                if (b[p] != 0xFF) { p++; continue; }
                while (p < b.Length && b[p] == 0xFF) p++;
                if (p >= b.Length) break;
                byte marker = b[p++];
                if (marker == 0xD9 || marker == 0xDA) break;
                if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) continue;
                if (p + 2 > b.Length) break;
                int len = (b[p] << 8) | b[p + 1];
                if (len < 2 || p + len > b.Length) break;
                int payload = p + 2;
                if (marker == 0xE1 && len >= 8 && payload + 6 <= b.Length &&
                    b[payload] == 0x45 && b[payload + 1] == 0x78 && b[payload + 2] == 0x69 && b[payload + 3] == 0x66 && b[payload + 4] == 0 && b[payload + 5] == 0)
                {
                    ParseTiff(b, payload + 6, info);
                }
                p += len;
            }
        }
        static void ScanEmbeddedExif(byte[] b, PhotoInfo info)
        {
            byte[] sig = new byte[] { 0x45, 0x78, 0x69, 0x66, 0, 0 };
            int limit = Math.Min(b.Length - 6, 64 * 1024 * 1024);
            for (int i = 0; i <= limit; i++)
            {
                if (b[i] == sig[0] && b[i + 1] == sig[1] && b[i + 2] == sig[2] && b[i + 3] == sig[3] && b[i + 4] == 0 && b[i + 5] == 0)
                    ParseTiff(b, i + 6, info);
            }
            // Некоторые RAW контейнеры содержат TIFF-подблоки без строки Exif.
            for (int i = 0; i + 8 < limit; i++)
            {
                if ((b[i] == 0x49 && b[i + 1] == 0x49 && b[i + 2] == 0x2A && b[i + 3] == 0) ||
                    (b[i] == 0x4D && b[i + 1] == 0x4D && b[i + 2] == 0 && b[i + 3] == 0x2A))
                {
                    ParseTiff(b, i, info);
                }
            }
        }
        static bool Starts(byte[] b, string s)
        {
            byte[] x = Encoding.ASCII.GetBytes(s);
            if (b == null || b.Length < x.Length) return false;
            for (int i = 0; i < x.Length; i++) if (b[i] != x[i]) return false;
            return true;
        }
        static List<IfdEntry> ParseMakerEntries(byte[] m, bool outerLittle)
        {
            List<IfdEntry> best = new List<IfdEntry>();
            int bestScore = 0;
            if (m == null || m.Length < 4) return best;

            // Nikon MakerNote v2 имеет собственный TIFF header после "Nikon\\0\\x02\\x10".
            if (m.Length > 18 && Starts(m, "Nikon\0") && m[6] == 2 && IsTiff(m, 10))
            {
                bool le = m[10] == 0x49;
                uint off = U32(m, 14, le);
                List<IfdEntry> n = ReadIfd(m, 10, 10 + (int)off, le);
                if (n.Count > 0) return n;
            }
            // Nikon MakerNote v1: IFD после 8-байтового заголовка.
            if (m.Length > 10 && Starts(m, "Nikon\0") && m[6] == 1)
            {
                List<IfdEntry> n = ReadIfd(m, 0, 8, outerLittle);
                if (n.Count > 0) return n;
            }
            // Fujifilm: сигнатура + 32-битный offset IFD.
            if (Starts(m, "FUJIFILM") && m.Length > 12)
            {
                uint off = U32(m, 8, true);
                List<IfdEntry> f = ReadIfd(m, 0, (int)off, true);
                if (Score(f) > bestScore) { best = f; bestScore = Score(f); }
                List<IfdEntry> f2 = ReadIfd(m, 0, 12, true);
                if (Score(f2) > bestScore) { best = f2; bestScore = Score(f2); }
            }
            int[] candidates = new int[] { 0, 4, 6, 8, 10, 12, 14, 16, 18, 20 };
            bool[] orders = new bool[] { outerLittle, !outerLittle, true, false };
            foreach (int pos in candidates)
            {
                if (pos + 2 > m.Length) continue;
                foreach (bool le in orders)
                {
                    List<IfdEntry> x = ReadIfd(m, 0, pos, le);
                    int sc = Score(x);
                    if (sc > bestScore) { best = x; bestScore = sc; }
                }
            }
            return best;
        }
        static int Score(List<IfdEntry> es)
        {
            int s = 0;
            if (Find(es, 0x00A7) != null) s += 100;
            if (Find(es, 0x0037) != null) s += 90;
            if (Find(es, 0x9050) != null) s += 100;
            if (Find(es, 0x1438) != null) s += 80;
            if (Find(es, 0x005D) != null) s += 80;
            if (Find(es, 0x0006) != null) s += 5;
            if (Find(es, 0x0007) != null) s += 5;
            return s;
        }
        // Sony MakerNotes have a 12-byte "SONY DSC \0\0\0" header.
        // IMPORTANT: offsets in the Sony IFD are relative to the TIFF/EXIF base,
        // not to the start of the MakerNote byte array. Parse against the full file.
        static List<IfdEntry> ParseSonyMakerEntries(PhotoInfo info)
        {
            if (info == null || info.SourceBytes == null || info.MakerNoteOffset < 0)
                return new List<IfdEntry>();

            byte[] file = info.SourceBytes;
            int maker = info.MakerNoteOffset;
            int ifd = maker;
            bool hasSonyHeader = false;

            if (maker + 12 <= file.Length)
            {
                string h9 = GetAscii(file, maker, 9);
                if (h9 == "SONY DSC " || h9 == "SONY CAM ")
                {
                    ifd = maker + 12;
                    hasSonyHeader = true;
                }
            }

            // Sony's documented MakerNote byte order is little-endian.
            // For old headerless Sony notes use the byte order inherited from EXIF.
            bool le = hasSonyHeader ? true : info.MakerNoteLittle;
            List<IfdEntry> entries = ReadIfd(file, info.TiffBase, ifd, le);
            if (Find(entries, 0x9050) != null) return entries;

            // Compatibility fallbacks for unusual SR2/JPEG variants. These are
            // only accepted when an actual 0x9050 tag is found.
            int[] starts = hasSonyHeader ? new int[] { maker + 12, maker, maker + 8 } : new int[] { maker, maker + 12, maker + 8 };
            foreach (int pos in starts)
            {
                if (pos < 0 || pos + 2 > file.Length) continue;
                List<IfdEntry> x = ReadIfd(file, info.TiffBase, pos, le);
                if (Find(x, 0x9050) != null) return x;
            }

            // Last fallback: older MakerNote layouts with offsets relative to the
            // beginning of the MakerNote itself (not the common Sony DSC format).
            if (info.MakerNote != null)
            {
                List<IfdEntry> local = ParseMakerEntries(info.MakerNote, info.MakerNoteLittle);
                if (Find(local, 0x9050) != null) return local;
            }
            return entries;
        }

        static uint SonyDecode(byte[] encrypted, int offset)
        {
            if (encrypted == null || offset < 0 || offset + 4 > encrypted.Length) return 0;
            // Sony cipher: clearByte^3 mod 249 = storedByte. Since cubing is
            // bijective over Z/249Z, the inverse lookup uniquely restores a byte.
            byte[] inverse = new byte[249];
            for (int x = 0; x <= 248; x++) inverse[(x * x * x) % 249] = (byte)x;
            byte[] d = new byte[4];
            for (int i = 0; i < 4; i++)
            {
                byte v = encrypted[offset + i];
                d[i] = v <= 248 ? inverse[v] : v;
            }
            return U32(d, 0, true);
        }
        static uint PentaxDecode(List<IfdEntry> es)
        {
            IfdEntry raw = Find(es, 0x005D);
            IfdEntry date = Find(es, 0x0006);
            IfdEntry time = Find(es, 0x0007);
            if (raw == null || date == null || time == null || raw.Data.Length < 4 || date.Data.Length < 4 || time.Data.Length < 3) return 0;
            byte[] t = new byte[4];
            Buffer.BlockCopy(time.Data, 0, t, 0, 3);
            uint r = U32BE(raw.Data, 0);
            uint d = U32BE(date.Data, 0);
            uint tm = U32BE(t, 0);
            return r ^ d ^ (0xFFFFFFFFu - tm);
        }
        static bool IsSony9050Offset32Family(string model)
        {
            string m = (model ?? "").ToUpperInvariant().Replace(" ", "");
            // Early full-frame Alpha bodies use index 0x32 in Sony Tag9050a.
            return m == "ILCE-7" || m == "ILCE-7R" || m == "ILCE-7S" || m == "ILCE-7M2";
        }
        static bool IsSony9050Family(string model)
        {
            string m = (model ?? "").ToUpperInvariant().Replace(" ", "");
            string[] known = new string[] {
                "ILCE-7M3", "ILCE-7RM2", "ILCE-7RM3", "ILCE-7RM4", "ILCE-7SM2",
                "ILCE-6100", "ILCE-6300", "ILCE-6400", "ILCE-6500", "ILCE-6600",
                "ILCE-7C", "ILCE-9", "ILCE-9M2", "ILCA-99M2", "ILCE-1", "ILCE-7M4",
                "ILCE-7RM5", "ILCE-7SM3", "ILME-FX3"
            };
            foreach (string k in known) if (m.Contains(k)) return true;
            return false;
        }
        static bool IsSony9050dFamily(string model)
        {
            string m = (model ?? "").ToUpperInvariant().Replace(" ", "");
            string[] known = new string[] { "ILCE-6700", "ILCE-7CM2", "ILCE-7CR", "ZV-E1", "ILCE-1M2", "ILCE-7M5", "ILCE-7RM6" };
            foreach (string k in known) if (m.Contains(k)) return true;
            return false;
        }
        static string GetAscii(byte[] b, int p, int n)
        {
            if (b == null || p < 0 || n < 0 || p + n > b.Length) return "";
            return Encoding.ASCII.GetString(b, p, n);
        }
        static byte[] FindCanonCameraInfoInMaker(byte[] maker, bool preferredLittle)
        {
            if (maker == null || maker.Length < 8) return null;
            bool[] orders = new bool[] { preferredLittle, !preferredLittle };
            int[] starts = new int[] { 0, 8, 12, 4, 16 };
            foreach (bool le in orders)
            {
                foreach (int pos in starts)
                {
                    List<IfdEntry> entries = ReadIfd(maker, 0, pos, le);
                    IfdEntry camera = Find(entries, 0x000D);
                    if (camera != null && camera.Data != null && camera.Data.Length >= 64)
                        return camera.Data;
                }
                // Некоторые CTMD записи содержат полный TIFF-блок, другие — чистый Canon IFD.
                if (IsTiff(maker, 0))
                {
                    uint first = U32(maker, 4, le);
                    if (first <= maker.Length - 2)
                    {
                        List<IfdEntry> entries = ReadIfd(maker, 0, (int)first, le);
                        IfdEntry camera = Find(entries, 0x000D);
                        if (camera != null && camera.Data != null && camera.Data.Length >= 64)
                            return camera.Data;
                    }
                }
            }
            return null;
        }
        static void ExtractCanonInfoFromTiff(byte[] b, int tiffBase, int makerOffset, bool le, PhotoInfo info)
        {
            if (b == null || makerOffset < 0 || makerOffset >= b.Length) return;
            List<IfdEntry> entries = ReadIfd(b, tiffBase, makerOffset, le);
            IfdEntry camera = Find(entries, 0x000D);
            IfdEntry fileInfo = Find(entries, 0x0093);
            if (camera != null && camera.Data != null && camera.Data.Length >= 64)
                info.CanonCameraInfo = camera.Data;
            if (fileInfo != null && fileInfo.Data != null && fileInfo.Data.Length >= 6)
                info.CanonFileInfo = fileInfo.Data;
        }
        static void ExtractCanonInfoFromMakerBytes(byte[] maker, bool preferredLittle, PhotoInfo info)
        {
            if (maker == null || maker.Length < 8) return;
            bool[] orders = new bool[] { preferredLittle, !preferredLittle };
            int[] starts = new int[] { 0, 8, 12, 4, 16 };
            foreach (bool le in orders)
            {
                foreach (int pos in starts)
                {
                    List<IfdEntry> entries = ReadIfd(maker, 0, pos, le);
                    IfdEntry camera = Find(entries, 0x000D);
                    IfdEntry fileInfo = Find(entries, 0x0093);
                    if (camera != null && camera.Data != null && camera.Data.Length >= 64)
                        info.CanonCameraInfo = camera.Data;
                    if (fileInfo != null && fileInfo.Data != null && fileInfo.Data.Length >= 6)
                        info.CanonFileInfo = fileInfo.Data;
                    if (info.CanonCameraInfo != null || info.CanonFileInfo != null) return;
                }
                if (IsTiff(maker, 0))
                {
                    uint first = U32(maker, 4, le);
                    if (first <= maker.Length - 2)
                    {
                        List<IfdEntry> entries = ReadIfd(maker, 0, (int)first, le);
                        IfdEntry camera = Find(entries, 0x000D);
                        IfdEntry fileInfo = Find(entries, 0x0093);
                        if (camera != null && camera.Data != null && camera.Data.Length >= 64)
                            info.CanonCameraInfo = camera.Data;
                        if (fileInfo != null && fileInfo.Data != null && fileInfo.Data.Length >= 6)
                            info.CanonFileInfo = fileInfo.Data;
                        if (info.CanonCameraInfo != null || info.CanonFileInfo != null) return;
                    }
                }
            }
        }
        static void ParseCtmdExifPayload(byte[] b, int p, int end, PhotoInfo info)
        {
            // CTMD record types 7/8/9 contain length-prefixed EXIF records:
            // uint32 size, uint32 TIFF/EXIF tag, followed by the tag payload.
            int guard = 0;
            while (p + 8 <= end && guard++ < 4096)
            {
                uint n = U32(b, p, true);
                uint tag = U32(b, p + 4, true);
                if (n < 8 || n > end - p) break;
                int dataOff = p + 8;
                int dataLen = (int)n - 8;
                if (tag == 0x927C && dataLen >= 8)
                {
                    byte[] maker = Slice(b, dataOff, dataLen);
                    ExtractCanonInfoFromMakerBytes(maker, true, info);
                }
                else if (tag == 0x8769 && dataLen >= 8)
                {
                    byte[] exif = Slice(b, dataOff, dataLen);
                    ExtractCanonInfoFromMakerBytes(exif, true, info);
                    // EXIF sub-blocks may wrap the Canon MakerNote in a TIFF IFD.
                    if (IsTiff(exif, 0))
                    {
                        bool le = exif[0] == 0x49;
                        uint first = U32(exif, 4, le);
                        if (first <= exif.Length - 2)
                        {
                            List<IfdEntry> nested = ReadIfd(exif, 0, (int)first, le);
                            IfdEntry mn = Find(nested, 0x927C);
                            if (mn != null) ExtractCanonInfoFromMakerBytes(mn.Data, le, info);
                        }
                    }
                }
                else if (tag == 0x000D && dataLen >= 64)
                {
                    // A few CR3 variants expose CameraInfo directly as a CTMD EXIF payload.
                    info.CanonCameraInfo = Slice(b, dataOff, dataLen);
                }
                p += (int)n;
            }
        }
        static void ParseCanonCmtIfd(byte[] b, int payload, int end, string atomType, PhotoInfo info)
        {
            if (payload < 0 || end > b.Length || payload + 2 > end) return;
            // Canon CR3 CMT1..CMT4 contain a Canon-specific little-endian TIFF IFD
            // without the usual II/MM + 42 + first-IFD TIFF header. Offsets are
            // relative to the beginning of the CMT atom payload.
            List<IfdEntry> entries = ReadIfd(b, payload, payload, true);
            if (entries.Count == 0) return;

            if (atomType == "CMT1")
            {
                IfdEntry make = Find(entries, 0x010F);
                IfdEntry model = Find(entries, 0x0110);
                IfdEntry date = Find(entries, 0x9003);
                if (make != null && info.Make.Length == 0) info.Make = Ascii(make.Data);
                if (model != null && info.Model.Length == 0) info.Model = Ascii(model.Data);
                if (date != null && info.Date.Length == 0) info.Date = Ascii(date.Data);
            }

            // Canon's CMT3 is the maker-note IFD in common CR3 layouts.
            // CameraInfo is Canon MakerNote tag 0x000D; FileInfo is 0x0093.
            IfdEntry camera = Find(entries, 0x000D);
            IfdEntry fileInfo = Find(entries, 0x0093);
            if (camera != null && camera.Data != null && camera.Data.Length >= 64)
                info.CanonCameraInfo = camera.Data;
            if (fileInfo != null && fileInfo.Data != null && fileInfo.Data.Length >= 6)
                info.CanonFileInfo = fileInfo.Data;

            // Some firmware layouts put a complete MakerNote or EXIF IFD in a CMT block.
            IfdEntry maker = Find(entries, 0x927C);
            if (maker != null && maker.Data != null && maker.Data.Length >= 8)
                ExtractCanonInfoFromMakerBytes(maker.Data, true, info);

            IfdEntry exif = Find(entries, 0x8769);
            if (exif != null && exif.Data != null && exif.Data.Length >= 8)
            {
                // Pointer-type IFD entries are read by the normal tree parser where
                // the block is a full TIFF; in CMT blocks the data may be a nested IFD.
                List<IfdEntry> nested = ReadIfd(b, payload, (int)exif.DataOffset, true);
                IfdEntry nestedMaker = Find(nested, 0x927C);
                if (nestedMaker != null)
                    ExtractCanonInfoFromMakerBytes(nestedMaker.Data, true, info);
                IfdEntry nestedCamera = Find(nested, 0x000D);
                if (nestedCamera != null && nestedCamera.Data.Length >= 64)
                    info.CanonCameraInfo = nestedCamera.Data;
            }
        }

        static void ParseCr3CmtAtoms(byte[] b, PhotoInfo info)
        {
            if (b == null || b.Length < 16) return;
            // CMT1/CMT2/CMT3/CMT4 are ISO-BMFF atoms. Scan atom type names,
            // then validate the big-endian atom size before reading the IFD.
            for (int typePos = 4; typePos + 4 <= b.Length; typePos++)
            {
                string typ = GetAscii(b, typePos, 4);
                if (typ != "CMT1" && typ != "CMT2" && typ != "CMT3" && typ != "CMT4") continue;
                int atomStart = typePos - 4;
                ulong atomSize = U32BE(b, atomStart);
                int headerSize = 8;
                if (atomSize == 1)
                {
                    if (atomStart + 16 > b.Length) continue;
                    ulong hi = U32BE(b, atomStart + 8);
                    ulong lo = U32BE(b, atomStart + 12);
                    atomSize = (hi << 32) | lo;
                    headerSize = 16;
                }
                else if (atomSize == 0)
                {
                    atomSize = (ulong)(b.Length - atomStart);
                }
                if (atomSize < (ulong)(headerSize + 2) || atomSize > (ulong)(b.Length - atomStart)) continue;
                int payload = atomStart + headerSize;
                int end = atomStart + (int)atomSize;
                ParseCanonCmtIfd(b, payload, end, typ, info);
                if (info.CanonCameraInfo != null || info.CanonFileInfo != null)
                {
                    // Keep scanning CMT1 after a counter block, so model metadata can
                    // still be discovered if it appears later in the file.
                }
            }
        }

        static void ParseCr3Ctmd(byte[] b, PhotoInfo info, bool extensionIsCr3)
        {
            if (b == null || b.Length < 32) return;
            // CTMD data samples live in the mdat atom. Search only for structurally valid
            // little-endian type-8 records to avoid treating arbitrary raw pixels as metadata.
            bool hasFtyp = GetAscii(b, 4, 4) == "ftyp";
            bool cr3 = extensionIsCr3 || (hasFtyp &&
                (GetAscii(b, 8, 4) == "crx " || GetAscii(b, 8, 4) == "heix" ||
                 GetAscii(b, 16, 4) == "crx " || GetAscii(b, 16, 4) == "heix"));
            // Compatible brands may appear later in the ftyp box.
            if (!cr3 && hasFtyp)
            {
                int brandEnd = Math.Min(b.Length, 128);
                for (int q = 8; q + 4 <= brandEnd; q += 4)
                {
                    string brand = GetAscii(b, q, 4);
                    if (brand == "crx " || brand == "heix") { cr3 = true; break; }
                }
            }
            info.IsCr3 = cr3;
            if (!cr3) return;
            ParseCr3CmtAtoms(b, info);
            for (int i = 0; i + 16 <= b.Length; i++)
            {
                if (U16(b, i + 4, true) != 8 || b[i + 6] != 1 || b[i + 7] != 1 ||
                    U16(b, i + 8, true) != 1 || U16(b, i + 10, true) != 0xFFFF) continue;
                uint recordSize = U32(b, i, true);
                if (recordSize < 20 || recordSize > b.Length - i) continue;
                ParseCtmdExifPayload(b, i + 12, i + (int)recordSize, info);
                if (info.CanonCameraInfo != null || info.CanonFileInfo != null) return;
            }
        }
        static uint CanonCountAt(byte[] data, int offset)
        {
            if (data == null || offset < 0 || offset + 4 > data.Length) return 0;
            uint le = U32(data, offset, true);
            uint be = U32(data, offset, false);
            if (le > 0 && le < 100000000 && le != 0xFFFFFFFF) return le;
            if (be > 0 && be < 100000000 && be != 0xFFFFFFFF) return be;
            return 0;
        }
        static string CanonModelKey(string model)
        {
            if (model == null) return "";
            StringBuilder sb = new StringBuilder();
            foreach (char c in model.ToUpperInvariant()) if (Char.IsLetterOrDigit(c)) sb.Append(c);
            return sb.ToString();
        }
        static void ReadCanonCounters(PhotoInfo info)
        {
            string key = CanonModelKey(info.Model);
            if (info.SourceBytes != null && info.MakerNoteOffset >= 0)
                ExtractCanonInfoFromTiff(info.SourceBytes, info.TiffBase, info.MakerNoteOffset, info.MakerNoteLittle, info);
            if (info.MakerNote != null && info.CanonCameraInfo == null && info.CanonFileInfo == null)
                ExtractCanonInfoFromMakerBytes(info.MakerNote, info.MakerNoteLittle, info);

            // Canon CR3 EOS R generations: values are camera-specific offsets within
            // Canon CameraInfo (tag 0x000D), not a universal EXIF field.
            int countOffset = -1;
            bool experimentalOffset = false;
            string modelLabel = info.Model;
            if (key.Contains("EOSR6MARKII") || key.Contains("EOSR6M2") || key.Contains("EOSR8") || key.Contains("EOSR50")) countOffset = 0x0D29;
            else if (key.Contains("EOSR5C")) countOffset = 0x0AF1;
            else if (key.Contains("EOSR5") && !key.Contains("MARKII") && !key.Contains("M2")) countOffset = 0x0AF1;
            else if (key.Contains("EOSR6") && !key.Contains("MARKII") && !key.Contains("M2") && !key.Contains("MARKIII") && !key.Contains("M3")) countOffset = 0x0AF1;
            else if (key == "CANONEOSR" || key.EndsWith("EOSR")) { countOffset = 0x0194; experimentalOffset = true; }
            else if (key.Contains("EOSRP")) { countOffset = 0x0960; experimentalOffset = true; }

            if (info.CanonCameraInfo != null)
            {
                if (countOffset >= 0)
                {
                    uint count = CanonCountAt(info.CanonCameraInfo, countOffset);
                    if (count > 0 && count < 1000000000 && count != 0xFFFFFFFF)
                    {
                        info.Counters.Add((experimentalOffset ? "Кандидат ShutterCount (Canon " : "ShutterCount (Canon ") + modelLabel + "): " + count.ToString("N0"));
                        info.Status = experimentalOffset
                            ? "Найден экспериментально подтверждённый кандидат Canon; сверить контрольными кадрами этой камеры"
                            : "Найден модельный счётчик Canon в CameraInfo (CR3/MakerNotes)";
                        info.Counters.Add("Примечание: на EOS R значение может включать механические и электронные срабатывания.");
                        return;
                    }
                    info.Status = "Canon " + modelLabel + " распознан, но значение CameraInfo по известному смещению не прошло проверку";
                    return;
                }
                // R6 Mark III's 0x086D is only a resettable image counter, never lifetime shutter count.
                if (key.Contains("EOSR6MARKIII") || key.Contains("EOSR6M3"))
                {
                    if (info.CanonCameraInfo.Length >= 0x086F)
                    {
                        uint imageCount = U16(info.CanonCameraInfo, 0x086D, true);
                        if (imageCount > 0 && imageCount != 0xFFFF)
                            info.Counters.Add("ImageCount (Canon EOS R6 Mark III; НЕ lifetime shutter count): " + imageCount.ToString("N0"));
                    }
                    info.Status = "Canon EOS R6 Mark III: в файле доступен только ImageCount, он сбрасывается при форматировании карты; пробег затвора не подтверждён";
                    return;
                }
            }

            // Legacy CR2: only selected 1D/1Ds bodies expose a shutter field in FileInfo.
            // Consumer EOS DSLR files (5D/6D/7D/xxD/Rebel) generally do not store lifetime count.
            bool legacy1D = key.Contains("EOS1D") || key.Contains("EOS1DS");
            bool unreliable1D3 = key.Contains("1DMARKIII") || key.Contains("1DSMARKIII") || key.Contains("1DMKIII") || key.Contains("1DSMKIII");
            bool supportedFileInfo = key.Contains("1DMARKII") || key.Contains("1DMARKIIN") || key.Contains("1DSMARKII") || key.Contains("1DMKIIN") || key.Contains("1DSMKII") || key == "CANONEOS1D" || key == "CANONEOS1DS";
            if (info.CanonFileInfo != null && legacy1D && supportedFileInfo && !unreliable1D3)
            {
                byte[] d = info.CanonFileInfo;
                uint count = 0;
                // 1D/1Ds Mark II variants store the 32-bit count with 16-bit words swapped.
                if (key.Contains("MARKII") || key.Contains("MKII"))
                {
                    byte[] swapped = new byte[] { d[4], d[5], d[2], d[3] };
                    count = U32(swapped, 0, info.MakerNoteLittle);
                }
                else count = U32(d, 2, info.MakerNoteLittle);
                if (count > 0 && count < 1000000000 && count != 0xFFFFFFFF)
                {
                    info.Counters.Add("ShutterCount (Canon EOS-1D/1Ds FileInfo): " + count.ToString("N0"));
                    info.Status = "Найден счётчик Canon в FileInfo для профессиональной серии 1D/1Ds";
                    return;
                }
            }
            if (legacy1D && unreliable1D3)
            {
                info.Status = "Canon EOS-1D/1Ds Mark III: найденные поля CameraInfo могут быть неверными или повторять номер файла; достоверный пробег не показывается";
                return;
            }
            if (info.IsCr3)
            {
                if (info.Model.Length == 0)
                    info.Status = "Canon CR3 распознан по контейнеру; модель/CameraInfo в доступных метаданных не найдены, пробег не извлечён";
                else
                    info.Status = "Canon CR3 распознан (" + info.Model + "), но подтверждённый счётчик для этой модели/версии прошивки в файле не найден";
            }
            else if (key.Contains("EOSR"))
                info.Status = "Canon распознан, но подтверждённый счётчик для этой модели/версии прошивки в файле не найден";
            else
                info.Status = "Canon CR2 распознан: эта модель обычно не записывает lifetime shutter count в фото; нужен USB/PTP или сервисная диагностика камеры";
        }
        static bool Matches(byte[] b, int p, byte[] x)
        {
            if (b == null || x == null || p < 0 || p + x.Length > b.Length) return false;
            for (int i = 0; i < x.Length; i++) if (b[p + i] != x[i]) return false;
            return true;
        }

        public static PhotoInfo ReadFile(string path)
        {
            PhotoInfo info = new PhotoInfo();
            byte[] b = File.ReadAllBytes(path);
            bool parsed = false;
            if (IsTiff(b, 0)) parsed = ParseTiff(b, 0, info);
            ParseJpegSegments(b, info);
            if (info.MakerNote == null || info.Make.Length == 0 || info.Model.Length == 0) ScanEmbeddedExif(b, info);
            string ext = Path.GetExtension(path).ToLowerInvariant();
            bool extensionIsCr3 = ext == ".cr3";
            ParseCr3Ctmd(b, info, extensionIsCr3);
            if ((ext == ".cr2" || ext == ".cr3") && info.Make.Length == 0) info.Make = "Canon";
            if (info.MakerNote != null || info.CanonCameraInfo != null || info.CanonFileInfo != null || info.IsCr3) parsed = true;
            if (!parsed && (info.Make.Length > 0 || info.Model.Length > 0)) parsed = true;
            if (info.Status.Length == 0) info.Status = parsed ? "Метаданные прочитаны" : "EXIF/TIFF блок не найден";
            return info;
        }
        public static void ReadCounters(PhotoInfo info)
        {
            if (info == null) return;
            string make = (info.Make ?? "").ToUpperInvariant();
            if (make.Contains("CANON") || info.IsCr3)
            {
                ReadCanonCounters(info);
                return;
            }
            if (info.MakerNote == null)
            {
                info.Status = "В файле не найден MakerNote производителя";
                return;
            }
            string model = (info.Model ?? "").ToUpperInvariant();
            List<IfdEntry> es = (make.Contains("SONY") || model.StartsWith("ILCE") || model.StartsWith("ILME"))
                ? ParseSonyMakerEntries(info)
                : ParseMakerEntries(info.MakerNote, info.Little);

            if (make.Contains("NIKON") || Find(es, 0x00A7) != null || Find(es, 0x0037) != null)
            {
                IfdEntry all = Find(es, 0x00A7);
                IfdEntry mech = Find(es, 0x0037);
                if (all != null)
                    info.Counters.Add("ShutterCount (общий счётчик экспозиций): " + EntryUInt(all).ToString("N0"));
                if (mech != null)
                    info.Counters.Add("MechanicalShutterCount (механический затвор): " + EntryUInt(mech).ToString("N0"));
                if (info.Counters.Count > 0) { info.Status = "Найден счётчик Nikon в MakerNotes"; return; }
            }

            if (make.Contains("SONY") || model.StartsWith("ILCE") || model.StartsWith("ILME"))
            {
                IfdEntry s = Find(es, 0x9050);
                if (s != null && s.Data != null)
                {
                    if (IsSony9050dFamily(model) && s.Data.Length >= 14)
                    {
                        uint c = SonyDecode(s.Data, 0x0A);
                        if (c > 0 && c < 1000000000) info.Counters.Add("Mechanical shutter actuations (Sony tag 0x9050d): " + c.ToString("N0"));
                    }
                    else if (IsSony9050Offset32Family(model) && s.Data.Length >= 0x36)
                    {
                        uint c = SonyDecode(s.Data, 0x32);
                        if (c > 0 && c < 1000000000) info.Counters.Add("ShutterCount (Sony tag 0x9050a, offset 0x32): " + c.ToString("N0"));
                    }
                    else if (IsSony9050Family(model) && s.Data.Length >= 0x3E)
                    {
                        uint c = SonyDecode(s.Data, 0x3A);
                        if (c > 0 && c < 1000000000) info.Counters.Add("ShutterCount (Sony tag 0x9050, offset 0x3A): " + c.ToString("N0"));
                    }
                    if (info.Counters.Count > 0) { info.Status = "Найден счётчик Sony; значение декодировано из MakerNotes"; return; }
                }

                // Legacy Sony DSLR fields documented in Sony MakerNotes. These are
                // plain 24-bit counters, unlike the encrypted 0x9050 block.
                IfdEntry legacy = Find(es, 0x0125);
                IfdEntry legacy450 = Find(es, 0x014A);
                bool is450500550 = model.Contains("A450") || model.Contains("A500") || model.Contains("A550");
                IfdEntry legacySelected = is450500550 ? legacy450 : legacy;
                if (legacySelected != null)
                {
                    uint c = EntryUInt(legacySelected) & 0x00FFFFFF;
                    if (c > 0 && c < 1000000000)
                    {
                        info.Counters.Add("ShutterCount (Sony legacy MakerNote): " + c.ToString("N0"));
                        info.Status = "Найден legacy ShutterCount Sony в MakerNotes";
                        return;
                    }
                }
                info.Status = "Sony распознан, но MakerNote 0x9050/legacy counter не содержит поддерживаемого значения. Нужен оригинальный ARW/JPEG прямо с камеры";
                return;
            }

            if (make.Contains("FUJI") || make.Contains("FUJIFILM"))
            {
                IfdEntry f = Find(es, 0x1438);
                if (f != null)
                {
                    uint c = EntryUInt(f);
                    if (c > 0) info.Counters.Add("ImageCount (счётчик кадров Fujifilm, может сбрасываться прошивкой): " + c.ToString("N0"));
                    info.Status = "Найден ImageCount Fujifilm; это не во всех моделях гарантированный lifetime shutter count";
                    return;
                }
            }

            if (make.Contains("PENTAX") || make.Contains("RICOH") || make.Contains("SAMSUNG"))
            {
                uint c = PentaxDecode(es);
                if (c > 0 && c < 1000000000)
                {
                    info.Counters.Add("ShutterCount (Pentax/Ricoh decoded): " + c.ToString("N0"));
                    info.Status = "Счётчик Pentax/Ricoh декодирован из MakerNotes";
                    return;
                }
            }

            info.Status = "MakerNote найден, но подтверждённый счётчик для этой марки/модели не распознан";
        }
    }
}
'@

try {
    Add-Type -TypeDefinition $source -Language CSharp -ErrorAction Stop
}
catch {
    Write-Host 'Не удалось запустить встроенный модуль чтения EXIF.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Read-Host 'Нажмите Enter для закрытия'
    exit 1
}

function Show-Header([string]$Text) {
    Write-Host ''
    Write-Host ('=' * 76) -ForegroundColor DarkCyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ('=' * 76) -ForegroundColor DarkCyan
}

$files = @($args | Where-Object { $_ -and $_.Trim() -ne '' })
if ($files.Count -eq 0) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = 'Выберите оригинальные фотографии или RAW-файлы'
        $dialog.Filter = 'Фото и RAW|*.jpg;*.jpeg;*.tif;*.tiff;*.dng;*.nef;*.nrw;*.arw;*.srf;*.sr2;*.cr2;*.cr3;*.raf;*.orf;*.rw2;*.pef;*.ptx;*.heic;*.heif|Все файлы|*.*'
        $dialog.Multiselect = $true
        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            Write-Host 'Файлы не выбраны.' -ForegroundColor Yellow
            exit 0
        }
        $files = @($dialog.FileNames)
    }
    catch {
        Write-Host 'Не удалось открыть окно выбора. Перетащите фото на BAT-файл.' -ForegroundColor Red
        Read-Host 'Нажмите Enter для закрытия'
        exit 1
    }
}

Write-Host ''
Write-Host 'CAMERA SHUTTER CHECKER 2.4.1' -ForegroundColor Cyan
Write-Host 'Автор проекта и разработчик: Emin Mirkarimov' -ForegroundColor White
Write-Host 'ExifTool не требуется. Интернет не требуется. Файлы остаются на компьютере.' -ForegroundColor Green
Write-Host 'Поддержка счётчиков зависит от производителя, модели и исходного формата файла.' -ForegroundColor Gray
Write-Host 'Практическая проверка на реальной камере пока выполнена на Sony; Canon CR2/CR3 поддерживается частично.' -ForegroundColor Yellow

$index = 0
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        Write-Host "Файл не найден: $file" -ForegroundColor Red
        continue
    }
    $index++
    Show-Header ("ФАЙЛ {0}: {1}" -f $index, [IO.Path]::GetFileName($file))
    try {
        $info = [CameraShutterCheckNative.Parser]::ReadFile((Resolve-Path -LiteralPath $file).Path)
        [CameraShutterCheckNative.Parser]::ReadCounters($info)
        Write-Host ("Производитель : {0}" -f $(if ($info.Make) { $info.Make } else { 'не определён' })) -ForegroundColor White
        Write-Host ("Модель        : {0}" -f $(if ($info.Model) { $info.Model } else { 'не определена' })) -ForegroundColor White
        Write-Host ("Дата съёмки   : {0}" -f $(if ($info.Date) { $info.Date } else { 'нет данных' })) -ForegroundColor Gray
        Write-Host ("Формат        : {0}" -f ([IO.Path]::GetExtension($file).TrimStart('.').ToUpperInvariant())) -ForegroundColor Gray
        Write-Host ("Статус        : {0}" -f $info.Status) -ForegroundColor $(if ($info.Counters.Count -gt 0) { 'Green' } else { 'Yellow' })
        if ($info.Counters.Count -gt 0) {
            Write-Host ''
            Write-Host 'НАЙДЕННЫЕ ЗНАЧЕНИЯ:' -ForegroundColor Green
            foreach ($c in $info.Counters) { Write-Host ('  ' + $c) -ForegroundColor Green }
        }
        else {
            Write-Host ''
            Write-Host 'Пробег не извлечён. Это НЕ означает, что пробег равен нулю.' -ForegroundColor Yellow
            Write-Host 'Попробуйте оригинальный RAW или JPEG прямо с карты памяти, без Lightroom/Photoshop.' -ForegroundColor Gray
        }
    }
    catch {
        Write-Host ("Ошибка чтения: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
}

Write-Host ''
Write-Host ('-' * 76) -ForegroundColor DarkGray
Write-Host 'ВАЖНО:' -ForegroundColor Yellow
Write-Host '1. Это самостоятельный парсер, он не вызывает ExifTool и не скачивает программы.'
Write-Host '2. Практическое тестирование на реальной камере на данный момент проводилось с Sony; список моделей в коде не означает, что каждая из них проверена отдельно.'
Write-Host '3. Sony: реализованы несколько вариантов MakerNotes 0x9050 и legacy-поля для выбранных Alpha/FX.'
Write-Host '4. Canon CR2/CR3: ЧАСТИЧНАЯ модельная поддержка. CR3: отдельные EOS R CameraInfo layout; CR2: отдельные EOS-1D/1Ds поколения Mark II. Многие Canon не записывают lifetime shutter count в фото.'
Write-Host '5. Nikon, Fujifilm и Pentax/Ricoh: соответствующие ветки парсера реализованы, но требуют дополнительной проверки на реальных камерах.'
Write-Host '6. Fujifilm ImageCount и некоторые Canon image counters не равны гарантированному lifetime mechanical shutter count.'
Write-Host '7. Panasonic, OM System/Olympus и Leica пока не заявляются как поддерживаемые производители счётчика.'
Write-Host '8. Если камера не записывает счётчик в файл, извлечь его из фотографии невозможно — может потребоваться USB/PTP или сервисная диагностика.'
Write-Host ''
Write-Host 'Проект и продукт: Emin Mirkarimov' -ForegroundColor Cyan
Write-Host 'Copyright (c) 2026 Emin Mirkarimov. All rights reserved.' -ForegroundColor Gray
Write-Host ('-' * 76) -ForegroundColor DarkGray
Write-Host ''
Read-Host 'Нажмите Enter для закрытия'
