# Photoshop PSD recipe for Magicrescue

A friend accidentally formatted her external hard disk that had all her Photoshop files on it. This is the magicrescue recipe and script I wrote to get them back.

The [Photoshop File Formats Specification](http://www.adobe.com/devnet-apps/photoshop/fileformatashtml/) is the primary resource I followed in the course of writing this script.

Most of the magic is in {{psd-scripts/rescue.pl}}, which parses the PSD headers and image data.

All of the sample files I could find use RLE, so the raw decoding isn't tested for now.

## Example of usage

```shell
mkdir out
magicrescue -d out -r ./psd /dev/sdb3
```