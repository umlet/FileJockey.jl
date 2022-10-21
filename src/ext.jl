


#const _d_Ext2exts = Dict{Symbol, Vector{String}}()
const _d_ext2Ext = Dict{Union{String, Nothing}, Symbol}()

function initext()
    _d_ext2Ext[nothing] = :__empty__
    _d_ext2Ext[""] = :__empty__

    for sdef in _v_EXTDEF
        ss = split(sdef, ',')
        extcanon = ss |> first |> lowercase |> Symbol
        for s in ss
            haskey(_d_ext2Ext, s)  &&  error("duplicate extension '$(s)' in config line: '$(sdef)'")
            _d_ext2Ext[s] = extcanon
        end
    end
end

function toExt(e::Union{AbstractString, Nothing})  # ext is extension, not path!
    e === nothing  &&  return _d_ext2Ext[e]

    e = uppercase(e)

    # check that an extension is not, by coincidence, clashing with special symbols
    @assert e != "__EMPTY__"
    @assert e != "__UNREGISTERED__"
    
    haskey(_d_ext2Ext, e)  &&  return _d_ext2Ext[e]
    return :__unregistered__
end

Ext(x) = ext(x) |> toExt

macro ex_str(s)
    :(Ext($s))  # "Ext(s)" alone does not work..
end

hasext(x::AbstractFsEntry, s::AbstractString) = ext(x) == s
hasext(s::AbstractString) = x -> ext(x) == s

hasExt(x::AbstractFsEntry, s::Symbol) = Ext(x) == s
hasExt(s::Symbol) = x -> Ext(x) == s







#------------------------------------------------------------------------------
const _v_EXTDEF = [
"360",
"3FR",
"3G2,3GP2",
"3GP,3GPP",
"A",
"AA",
"AAE",
"AAX",
"ACR",
"AFM,ACFM,AMFM",
"AI,AIT",
"AIFF,AIF,AIFC",
"APE",
"ARQ",
"ARW",
"ASF",
"AVI",
"AVIF",
"BMP,DIB",
"BPG",
"BTF",
"CHM",
"COS",
"CR2",
"CR3",
"CRM",
"CRW,CIFF",
"CS1",
"CSV",
"CZI",
"DCM,DC3,DIC,DICM",
"DCP",
"DCR",
"DFONT",
"DIVX",
"DJVU,DJV",
"DNG",
"DOC,DOT",
"DOCX,DOCM",
"DOTX,DOTM",
"DPX",
"DR4",
"DSS,DS2",
"DYLIB",
"DV",
"DVB",
"DVR-MS",
"EIP",
"EPS,EPSF,PS",
"EPUB",
"ERF",
"EXE,DLL",
"EXIF",
"EXR",
"EXV",
"F4A,F4B,F4P,F4V",
"FFF",
"FITS",
"FLA",
"FLAC",
"FLIF",
"FLV",
"FPF",
"FPX",
"GIF",
"GPR",
"GZ,GZIP",
"HDP,WDP,JXR",
"HDR",
"HEIC,HEIF,HIF",
"HTML,HTM,XHTML",
"ICC,ICM",
"ICO,CUR",
"ICS,ICAL",
"IDML",
"IIQ",
"IND,INDD,INDT",
"INSP",
"INSV",
"INX",
"ISO",
"ITC",
"J2C,J2K,JPC",
"JP2,JPF,JPM,JPX",
"JPEG,JPG,JPE",
"JSON",
"JXL",
"K25",
"KDC",
"KEY,KTH",
"LA",
"LFP,LFR",
"LIF",
"LNK",
"LRV",
"M2TS,MTS,M2T,TS",
"M4A,M4B,M4P,M4V",
"MACOS",
"MAX",
"MEF",
"MIE",
"MIFF,MIF",
"MKA,MKV,MKS",
"MOBI,AZW,AZW3",
"MODD",
"MOI",
"MOS",
"MOV,QT",
"MP3",
"MP4",
"MPC",
"MPEG,MPG,M2V",
"MPO",
"MQV",
"MRW",
"MRC",
"MXF",
"NEF",
"NKSC",
"NMBTEMPLATE",
"NRW",
"NUMBERS",
"O",
"ODB,ODC,ODF,ODG",
"ODI,ODP,ODS,ODT",
"OFR",
"OGG,OGV",
"ONP",
"OPUS",
"ORF,ORI",
"OTF",
"PAC",
"PAGES",
"PCD",
"PCX",
"PDB,PRC",
"PDF",
"PEF",
"PFA,PFB",
"PFM",
"PGF",
"PICT,PCT",
"PLIST",
"PMP",
"PNG, JNG,MNG",
"PPM,PBM,PGM",
"PPT,PPS,POT",
"POTX,POTM",
"PPAX,PPAM",
"PPSX,PPSM",
"PPTX,PPTM",
"PSD,PSB,PSDT",
"PSP,PSPIMAGE",
"QTIF,QTI,QIF",
"R3D",
"RA",
"RAF",
"RAM,RPM",
"RAR",
"RAW",
"RIFF,RIF",
"RM,RV,RMVB",
"RSRC",
"RTF",
"RW2",
"RWL",
"RWZ",
"SEQ",
"SKETCH",
"SO",
"SR2",
"SRF",
"SRW",
"SVG",
"SWF",
"THM",
"THMX",
"TIFF,TIF",
"TTF,TTC",
"TORRENT",
"TXT",
"VCF,VCARD",
"VOB",
"VRD",
"VSD",
"WAV",
"WEBM",
"WEBP",
"WMA,WMV",
"WTV",
"WV",
"X3F",
"XCF",
"XLS,XLT",
"XLSX,XLSM,XLSB",
"XLTX,XLTM",
"XMP",
"ZIP",
]

