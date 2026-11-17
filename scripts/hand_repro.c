/*
 * hand_repro.c — one-shot driver for the tree's own decoder fuzz target.
 *
 * tools/target_dec_fuzzer.c defines LLVMFuzzerTestOneInput() but no main(); the
 * OSS-Fuzz builder supplies the libFuzzer runtime instead.  This driver reads a
 * single input file, hands it to that function once and exits, so a recorded PoC
 * replays without libFuzzer, without a corpus and without mutation.
 *
 * The decoder is fixed at link time by -DFFMPEG_DECODER=<name> (the same decoder
 * the OSS-Fuzz target name pins), so the input cannot steer which codec runs.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int main(int argc, char **argv)
{
    FILE *file;
    uint8_t *data;
    long size;

    if (argc != 2) {
        fprintf(stderr, "usage: %s <input>\n", argv[0]);
        return 2;
    }
    file = fopen(argv[1], "rb");
    if (!file) {
        perror(argv[1]);
        return 2;
    }
    if (fseek(file, 0, SEEK_END) != 0 || (size = ftell(file)) < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fprintf(stderr, "%s: cannot determine size\n", argv[1]);
        fclose(file);
        return 2;
    }
    data = malloc(size ? (size_t)size : 1);
    if (!data) {
        fprintf(stderr, "%s: out of memory\n", argv[1]);
        fclose(file);
        return 2;
    }
    if (fread(data, 1, (size_t)size, file) != (size_t)size) {
        fprintf(stderr, "%s: short read\n", argv[1]);
        free(data);
        fclose(file);
        return 2;
    }
    fclose(file);

    LLVMFuzzerTestOneInput(data, (size_t)size);

    free(data);
    return 0;
}
