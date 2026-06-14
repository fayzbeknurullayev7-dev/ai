files = [
    "lib/features/slides/data/slides_repository.dart",
    "lib/features/slides/presentation/slides_provider.dart",
    "lib/features/slides/presentation/slides_page.dart",
    "lib/features/video/data/video_repository.dart",
    "lib/features/video/presentation/video_provider.dart",
    "lib/features/video/presentation/video_page.dart",
    "lib/features/home/presentation/pages/home_shell.dart",
    "lib/features/home/chat_mode.dart",
    "lib/core/constants/api_constants.dart",
]
for f in files:
    s = open(f).read()
    ob, cb, op, cp = s.count("{"), s.count("}"), s.count("("), s.count(")")
    st = "OK" if ob == cb and op == cp else "MISMATCH"
    print(st, f.split("/")[-1], ob, cb, op, cp)
