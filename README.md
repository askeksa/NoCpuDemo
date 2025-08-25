# No-CPU demo and framework

This is the source for the [No-CPU Challenge](https://no-cpu.dev) [invitation demo](https://www.pouet.net/prod.php?which=104753), including framework, Protracker music converter and all graphics and music assets.

Build the demo by running
```
dart run --enable-asserts no_cpu/bin/main.dart
```
The demo build code assumes this repository is checked out alongside the [NoCpuChallenge](https://github.com/askeksa/NoCpuChallenge) repository and will place its output `chip.dat` file into the `runner` directory of that checkout.

The structure of the code is as follows:
- `no_cpu/lib`: A general-purpose Dart package for no-CPU demo development. Mainly geared towards AGA, though it should be easy to adapt to OCS.
- `no_cpu/bin`: Code specific to the demo.
- `no_cpu/bin/effects`: The various effects in the demo in a somewhat reusable form.
- `no_cpu/bin/parts`: The various parts of the demo.
- `no_cpu/bin/base.dart`: Demo base classes containing music replay, frame dispatch and scripting systems generally useful to demos, though somewhat more opinionated than the general package.
- `no_cpu/bin/main.dart`: Main entry point for the demo.
- `no_cpu/example`: Some examples, mainly stand-alone instances of the effects.

The framework is generally designed to be run with asserts enabled. Many important safety checks will be skipped if asserts are disabled, though the code will still produce the correct result when used correctly.

The code is shared under the [zlib](LICENSE.txt) license. Graphics and music [assets](assets) are shared under the [CC BY-NC](https://creativecommons.org/licenses/by-nc/4.0/deed.en) license.
