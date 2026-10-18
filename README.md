# wf-toolchain

Prebuilt **Linux x86_64** toolchain for writing-factory lanes that can't build their own (claude.ai sandboxes, cold containers): **Chez Scheme 10.1.0 + Idris2 0.7.0**, in one relocatable prefix. It holds open-source compilers only; there's no project content here.

```bash
curl -fsSL https://raw.githubusercontent.com/Scottieroche/wf-toolchain/main/fetch.sh | bash -s -- /path/to/writing-factory
source /path/to/writing-factory/.tools/env.sh
```

Built by `.github/workflows/build-linux.yml` on Ubuntu 22.04 (glibc 2.35 floor). Each release carries `BUILD-INFO.txt`, which records the relocation test: it runs from a different path, in an empty environment, with no system Chez, and compiles and runs an Idris program.

Licences: Chez Scheme (Apache-2.0), Idris2 (BSD-3-Clause); GMP (LGPL-3.0) is included only if the build links it at runtime.
