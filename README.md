## Pegged Token Converter

The pegged token converter enables direct 1:1 conversion between two tokens without any fees or slippage.

The owner is responsible for supplying token liquidity, after which users can freely execute conversions. In its default mode, the converter only allows for unidirectional conversions. The owner can optionally enable bidirectional conversions, such that users can convert back the other way. As all liquidity on the contract belongs to the owner, they can withdraw it at any time.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```