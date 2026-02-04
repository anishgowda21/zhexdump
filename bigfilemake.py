TARGET_SIZE_MB = 500
CHUNK_LINES = 10_000
LINE = """Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's 
standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a 
type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining 
essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, 
and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.
"""


chunk = LINE * CHUNK_LINES
chunk_bytes = len(chunk.encode("utf-8"))

target_bytes = TARGET_SIZE_MB * 1024 * 1024

written = 0

with open(f"huge_{TARGET_SIZE_MB}M.txt", "w", encoding="utf-8") as f:
    while written < target_bytes:
        f.write(chunk)
        written += chunk_bytes

print(f"Generated huge.txt ({written / 1024 / 1024:.2f} MB)")
