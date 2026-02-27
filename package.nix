{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  curl,
  copyDesktopItems,
  makeDesktopItem,
  nodePackages,
  nodejs_24,
  electron_40,
  libicns,
  unzip,
  python3,
  pkg-config,
  gnumake,
  gcc,
  binutils,
  writeShellApplication,
  nix,
  runCommand,
}:
let
  pname = "codex-app";
  codexVersion = "26.226.940";
  version = codexVersion;

  # For reproducibility we use the versioned artifact published in appcast.xml.
  codexSrc = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/Codex-darwin-arm64-${codexVersion}.zip";
    hash = "sha256-2cURhFonosAlWqtU0s5t11yX2AxLiiqP2tjRlPqM1UU=";
  };

  updateScript = writeShellApplication {
    name = "update-codex-app";
    runtimeInputs = [
      curl
      python3
      nix
    ];
    text = ''
      set -euo pipefail

      repo_root="$(pwd)"
      package_file="$repo_root/package.nix"

      if [ ! -f "$package_file" ]; then
        echo "package.nix not found in current directory: $repo_root" >&2
        exit 1
      fi

      appcast_url="https://persistent.oaistatic.com/codex-app-prod/appcast.xml"
      appcast_xml="$(mktemp)"
      trap 'rm -f "$appcast_xml"' EXIT

      curl -fsSL "$appcast_url" -o "$appcast_xml"

      read -r latest_version latest_zip_url < <(
        python3 - "$appcast_xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

ns = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
root = ET.parse(sys.argv[1]).getroot()
item = root.find("./channel/item")
if item is None:
    raise SystemExit("No <item> found in appcast.xml")

version = item.findtext("sparkle:shortVersionString", namespaces=ns)
if not version:
    version = item.findtext("title")
if not version:
    raise SystemExit("No version found in appcast item")

enclosure = item.find("enclosure")
if enclosure is None:
    raise SystemExit("No enclosure URL found in appcast item")

url = enclosure.attrib.get("url", "").strip()
if not url:
    raise SystemExit("Enclosure URL is empty")

print(version, url)
PY
      )

      current_version="$(python3 - "$package_file" <<'PY'
import re,sys
text = open(sys.argv[1], "r", encoding="utf-8").read()
m = re.search(r'codexVersion = "([^"]+)";', text)
print(m.group(1) if m else "")
PY
      )"

      if [ "$current_version" = "$latest_version" ] && [ "''${FORCE_HASH_CHECK:-0}" != "1" ]; then
        echo "Current version: $current_version"
        echo "Latest version:  $latest_version"
        echo "Already up to date (version check)."
        exit 0
      fi

      latest_hash="$(nix store prefetch-file "$latest_zip_url" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["hash"])')"

      current_hash="$(python3 - "$package_file" <<'PY'
import re,sys
text = open(sys.argv[1], "r", encoding="utf-8").read()
m = re.search(r'codexSrc = fetchurl \{.*?hash = "(sha256-[^"]+)";', text, re.S)
print(m.group(1) if m else "")
PY
      )"

      echo "Current version: $current_version"
      echo "Latest version:  $latest_version"
      echo "Current hash:    $current_hash"
      echo "Latest hash:     $latest_hash"

      if [ "$current_version" = "$latest_version" ] && [ "$current_hash" = "$latest_hash" ]; then
        echo "Already up to date."
        exit 0
      fi

      if [ "''${APPLY_UPDATES:-0}" != "1" ]; then
        echo "Update available, but running in check-only mode."
        echo "Set APPLY_UPDATES=1 to write changes into package.nix."
        exit 0
      fi

      python3 - "$package_file" "$latest_version" "$latest_hash" <<'PY'
import re
import sys

path, version, hash_value = sys.argv[1:4]
text = open(path, "r", encoding="utf-8").read()

text, n1 = re.subn(r'codexVersion = "[^"]+";', f'codexVersion = "{version}";', text, count=1)
text, n2 = re.subn(
    r'(codexSrc = fetchurl \{.*?hash = )"sha256-[^"]+";',
    rf'\1"{hash_value}";',
    text,
    count=1,
    flags=re.S,
)

if n1 != 1 or n2 != 1:
    raise SystemExit("Failed to patch package.nix")

open(path, "w", encoding="utf-8").write(text)
PY

      echo "Updated package.nix to version $latest_version"
    '';
  };

  nativeModulesSrc = runCommand "codex-native-modules-src" { } ''
    mkdir -p "$out"

    cat > "$out/package.json" <<'JSON'
{
  "name": "codex-native-modules",
  "private": true,
  "version": "1.0.0",
  "description": "Native modules rebuilt for Codex on Linux",
  "dependencies": {
    "better-sqlite3": "12.5.0",
    "node-pty": "1.1.0"
  }
}
JSON

    cat > "$out/package-lock.json" <<'JSON'
{
  "name": "codex-native-modules",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "codex-native-modules",
      "version": "1.0.0",
      "dependencies": {
        "better-sqlite3": "12.5.0",
        "node-pty": "1.1.0"
      }
    },
    "node_modules/base64-js": {
      "version": "1.5.1",
      "resolved": "https://registry.npmjs.org/base64-js/-/base64-js-1.5.1.tgz",
      "integrity": "sha512-AKpaYlHn8t4SVbOHCy+b5+KKgvR4vrsD8vbvrbiQJps7fKDTkjkDry6ji0rUJjC0kzbNePLwzxq8iypo41qeWA==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/feross"
        },
        {
          "type": "patreon",
          "url": "https://www.patreon.com/feross"
        },
        {
          "type": "consulting",
          "url": "https://feross.org/support"
        }
      ],
      "license": "MIT"
    },
    "node_modules/better-sqlite3": {
      "version": "12.5.0",
      "resolved": "https://registry.npmjs.org/better-sqlite3/-/better-sqlite3-12.5.0.tgz",
      "integrity": "sha512-WwCZ/5Diz7rsF29o27o0Gcc1Du+l7Zsv7SYtVPG0X3G/uUI1LqdxrQI7c9Hs2FWpqXXERjW9hp6g3/tH7DlVKg==",
      "hasInstallScript": true,
      "license": "MIT",
      "dependencies": {
        "bindings": "^1.5.0",
        "prebuild-install": "^7.1.1"
      },
      "engines": {
        "node": "20.x || 22.x || 23.x || 24.x || 25.x"
      }
    },
    "node_modules/bindings": {
      "version": "1.5.0",
      "resolved": "https://registry.npmjs.org/bindings/-/bindings-1.5.0.tgz",
      "integrity": "sha512-p2q/t/mhvuOj/UeLlV6566GD/guowlr0hHxClI0W9m7MWYkL1F0hLo+0Aexs9HSPCtR1SXQ0TD3MMKrXZajbiQ==",
      "license": "MIT",
      "dependencies": {
        "file-uri-to-path": "1.0.0"
      }
    },
    "node_modules/bl": {
      "version": "4.1.0",
      "resolved": "https://registry.npmjs.org/bl/-/bl-4.1.0.tgz",
      "integrity": "sha512-1W07cM9gS6DcLperZfFSj+bWLtaPGSOHWhPiGzXmvVJbRLdG82sH/Kn8EtW1VqWVA54AKf2h5k5BbnIbwF3h6w==",
      "license": "MIT",
      "dependencies": {
        "buffer": "^5.5.0",
        "inherits": "^2.0.4",
        "readable-stream": "^3.4.0"
      }
    },
    "node_modules/buffer": {
      "version": "5.7.1",
      "resolved": "https://registry.npmjs.org/buffer/-/buffer-5.7.1.tgz",
      "integrity": "sha512-EHcyIPBQ4BSGlvjB16k5KgAJ27CIsHY/2JBmCRReo48y9rQ3MaUzWX3KVlBa4U7MyX02HdVj0K7C3WaB3ju7FQ==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/feross"
        },
        {
          "type": "patreon",
          "url": "https://www.patreon.com/feross"
        },
        {
          "type": "consulting",
          "url": "https://feross.org/support"
        }
      ],
      "license": "MIT",
      "dependencies": {
        "base64-js": "^1.3.1",
        "ieee754": "^1.1.13"
      }
    },
    "node_modules/chownr": {
      "version": "1.1.4",
      "resolved": "https://registry.npmjs.org/chownr/-/chownr-1.1.4.tgz",
      "integrity": "sha512-jJ0bqzaylmJtVnNgzTeSOs8DPavpbYgEr/b0YL8/2GO3xJEhInFmhKMUnEJQjZumK7KXGFhUy89PrsJWlakBVg==",
      "license": "ISC"
    },
    "node_modules/decompress-response": {
      "version": "6.0.0",
      "resolved": "https://registry.npmjs.org/decompress-response/-/decompress-response-6.0.0.tgz",
      "integrity": "sha512-aW35yZM6Bb/4oJlZncMH2LCoZtJXTRxES17vE3hoRiowU2kWHaJKFkSBDnDR+cm9J+9QhXmREyIfv0pji9ejCQ==",
      "license": "MIT",
      "dependencies": {
        "mimic-response": "^3.1.0"
      },
      "engines": {
        "node": ">=10"
      },
      "funding": {
        "url": "https://github.com/sponsors/sindresorhus"
      }
    },
    "node_modules/deep-extend": {
      "version": "0.6.0",
      "resolved": "https://registry.npmjs.org/deep-extend/-/deep-extend-0.6.0.tgz",
      "integrity": "sha512-LOHxIOaPYdHlJRtCQfDIVZtfw/ufM8+rVj649RIHzcm/vGwQRXFt6OPqIFWsm2XEMrNIEtWR64sY1LEKD2vAOA==",
      "license": "MIT",
      "engines": {
        "node": ">=4.0.0"
      }
    },
    "node_modules/detect-libc": {
      "version": "2.1.2",
      "resolved": "https://registry.npmjs.org/detect-libc/-/detect-libc-2.1.2.tgz",
      "integrity": "sha512-Btj2BOOO83o3WyH59e8MgXsxEQVcarkUOpEYrubB0urwnN10yQ364rsiByU11nZlqWYZm05i/of7io4mzihBtQ==",
      "license": "Apache-2.0",
      "engines": {
        "node": ">=8"
      }
    },
    "node_modules/end-of-stream": {
      "version": "1.4.5",
      "resolved": "https://registry.npmjs.org/end-of-stream/-/end-of-stream-1.4.5.tgz",
      "integrity": "sha512-ooEGc6HP26xXq/N+GCGOT0JKCLDGrq2bQUZrQ7gyrJiZANJ/8YDTxTpQBXGMn+WbIQXNVpyWymm7KYVICQnyOg==",
      "license": "MIT",
      "dependencies": {
        "once": "^1.4.0"
      }
    },
    "node_modules/expand-template": {
      "version": "2.0.3",
      "resolved": "https://registry.npmjs.org/expand-template/-/expand-template-2.0.3.tgz",
      "integrity": "sha512-XYfuKMvj4O35f/pOXLObndIRvyQ+/+6AhODh+OKWj9S9498pHHn/IMszH+gt0fBCRWMNfk1ZSp5x3AifmnI2vg==",
      "license": "(MIT OR WTFPL)",
      "engines": {
        "node": ">=6"
      }
    },
    "node_modules/file-uri-to-path": {
      "version": "1.0.0",
      "resolved": "https://registry.npmjs.org/file-uri-to-path/-/file-uri-to-path-1.0.0.tgz",
      "integrity": "sha512-0Zt+s3L7Vf1biwWZ29aARiVYLx7iMGnEUl9x33fbB/j3jR81u/O2LbqK+Bm1CDSNDKVtJ/YjwY7TUd5SkeLQLw==",
      "license": "MIT"
    },
    "node_modules/fs-constants": {
      "version": "1.0.0",
      "resolved": "https://registry.npmjs.org/fs-constants/-/fs-constants-1.0.0.tgz",
      "integrity": "sha512-y6OAwoSIf7FyjMIv94u+b5rdheZEjzR63GTyZJm5qh4Bi+2YgwLCcI/fPFZkL5PSixOt6ZNKm+w+Hfp/Bciwow==",
      "license": "MIT"
    },
    "node_modules/github-from-package": {
      "version": "0.0.0",
      "resolved": "https://registry.npmjs.org/github-from-package/-/github-from-package-0.0.0.tgz",
      "integrity": "sha512-SyHy3T1v2NUXn29OsWdxmK6RwHD+vkj3v8en8AOBZ1wBQ/hCAQ5bAQTD02kW4W9tUp/3Qh6J8r9EvntiyCmOOw==",
      "license": "MIT"
    },
    "node_modules/ieee754": {
      "version": "1.2.1",
      "resolved": "https://registry.npmjs.org/ieee754/-/ieee754-1.2.1.tgz",
      "integrity": "sha512-dcyqhDvX1C46lXZcVqCpK+FtMRQVdIMN6/Df5js2zouUsqG7I6sFxitIC+7KYK29KdXOLHdu9zL4sFnoVQnqaA==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/feross"
        },
        {
          "type": "patreon",
          "url": "https://www.patreon.com/feross"
        },
        {
          "type": "consulting",
          "url": "https://feross.org/support"
        }
      ],
      "license": "BSD-3-Clause"
    },
    "node_modules/inherits": {
      "version": "2.0.4",
      "resolved": "https://registry.npmjs.org/inherits/-/inherits-2.0.4.tgz",
      "integrity": "sha512-k/vGaX4/Yla3WzyMCvTQOXYeIHvqOKtnqBduzTHpzpQZzAskKMhZ2K+EnBiSM9zGSoIFeMpXKxa4dYeZIQqewQ==",
      "license": "ISC"
    },
    "node_modules/ini": {
      "version": "1.3.8",
      "resolved": "https://registry.npmjs.org/ini/-/ini-1.3.8.tgz",
      "integrity": "sha512-JV/yugV2uzW5iMRSiZAyDtQd+nxtUnjeLt0acNdw98kKLrvuRVyB80tsREOE7yvGVgalhZ6RNXCmEHkUKBKxew==",
      "license": "ISC"
    },
    "node_modules/mimic-response": {
      "version": "3.1.0",
      "resolved": "https://registry.npmjs.org/mimic-response/-/mimic-response-3.1.0.tgz",
      "integrity": "sha512-z0yWI+4FDrrweS8Zmt4Ej5HdJmky15+L2e6Wgn3+iK5fWzb6T3fhNFq2+MeTRb064c6Wr4N/wv0DzQTjNzHNGQ==",
      "license": "MIT",
      "engines": {
        "node": ">=10"
      },
      "funding": {
        "url": "https://github.com/sponsors/sindresorhus"
      }
    },
    "node_modules/minimist": {
      "version": "1.2.8",
      "resolved": "https://registry.npmjs.org/minimist/-/minimist-1.2.8.tgz",
      "integrity": "sha512-2yyAR8qBkN3YuheJanUpWC5U3bb5osDywNB8RzDVlDwDHbocAJveqqj1u8+SVD7jkWT4yvsHCpWqqWqAxb0zCA==",
      "license": "MIT",
      "funding": {
        "url": "https://github.com/sponsors/ljharb"
      }
    },
    "node_modules/mkdirp-classic": {
      "version": "0.5.3",
      "resolved": "https://registry.npmjs.org/mkdirp-classic/-/mkdirp-classic-0.5.3.tgz",
      "integrity": "sha512-gKLcREMhtuZRwRAfqP3RFW+TK4JqApVBtOIftVgjuABpAtpxhPGaDcfvbhNvD0B8iD1oUr/txX35NjcaY6Ns/A==",
      "license": "MIT"
    },
    "node_modules/napi-build-utils": {
      "version": "2.0.0",
      "resolved": "https://registry.npmjs.org/napi-build-utils/-/napi-build-utils-2.0.0.tgz",
      "integrity": "sha512-GEbrYkbfF7MoNaoh2iGG84Mnf/WZfB0GdGEsM8wz7Expx/LlWf5U8t9nvJKXSp3qr5IsEbK04cBGhol/KwOsWA==",
      "license": "MIT"
    },
    "node_modules/node-abi": {
      "version": "3.87.0",
      "resolved": "https://registry.npmjs.org/node-abi/-/node-abi-3.87.0.tgz",
      "integrity": "sha512-+CGM1L1CgmtheLcBuleyYOn7NWPVu0s0EJH2C4puxgEZb9h8QpR9G2dBfZJOAUhi7VQxuBPMd0hiISWcTyiYyQ==",
      "license": "MIT",
      "dependencies": {
        "semver": "^7.3.5"
      },
      "engines": {
        "node": ">=10"
      }
    },
    "node_modules/node-addon-api": {
      "version": "7.1.1",
      "resolved": "https://registry.npmjs.org/node-addon-api/-/node-addon-api-7.1.1.tgz",
      "integrity": "sha512-5m3bsyrjFWE1xf7nz7YXdN4udnVtXK6/Yfgn5qnahL6bCkf2yKt4k3nuTKAtT4r3IG8JNR2ncsIMdZuAzJjHQQ==",
      "license": "MIT"
    },
    "node_modules/node-pty": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/node-pty/-/node-pty-1.1.0.tgz",
      "integrity": "sha512-20JqtutY6JPXTUnL0ij1uad7Qe1baT46lyolh2sSENDd4sTzKZ4nmAFkeAARDKwmlLjPx6XKRlwRUxwjOy+lUg==",
      "hasInstallScript": true,
      "license": "MIT",
      "dependencies": {
        "node-addon-api": "^7.1.0"
      }
    },
    "node_modules/once": {
      "version": "1.4.0",
      "resolved": "https://registry.npmjs.org/once/-/once-1.4.0.tgz",
      "integrity": "sha512-lNaJgI+2Q5URQBkccEKHTQOPaXdUxnZZElQTZY0MFUAuaEqe1E+Nyvgdz/aIyNi6Z9MzO5dv1H8n58/GELp3+w==",
      "license": "ISC",
      "dependencies": {
        "wrappy": "1"
      }
    },
    "node_modules/prebuild-install": {
      "version": "7.1.3",
      "resolved": "https://registry.npmjs.org/prebuild-install/-/prebuild-install-7.1.3.tgz",
      "integrity": "sha512-8Mf2cbV7x1cXPUILADGI3wuhfqWvtiLA1iclTDbFRZkgRQS0NqsPZphna9V+HyTEadheuPmjaJMsbzKQFOzLug==",
      "deprecated": "No longer maintained. Please contact the author of the relevant native addon; alternatives are available.",
      "license": "MIT",
      "dependencies": {
        "detect-libc": "^2.0.0",
        "expand-template": "^2.0.3",
        "github-from-package": "0.0.0",
        "minimist": "^1.2.3",
        "mkdirp-classic": "^0.5.3",
        "napi-build-utils": "^2.0.0",
        "node-abi": "^3.3.0",
        "pump": "^3.0.0",
        "rc": "^1.2.7",
        "simple-get": "^4.0.0",
        "tar-fs": "^2.0.0",
        "tunnel-agent": "^0.6.0"
      },
      "bin": {
        "prebuild-install": "bin.js"
      },
      "engines": {
        "node": ">=10"
      }
    },
    "node_modules/pump": {
      "version": "3.0.3",
      "resolved": "https://registry.npmjs.org/pump/-/pump-3.0.3.tgz",
      "integrity": "sha512-todwxLMY7/heScKmntwQG8CXVkWUOdYxIvY2s0VWAAMh/nd8SoYiRaKjlr7+iCs984f2P8zvrfWcDDYVb73NfA==",
      "license": "MIT",
      "dependencies": {
        "end-of-stream": "^1.1.0",
        "once": "^1.3.1"
      }
    },
    "node_modules/rc": {
      "version": "1.2.8",
      "resolved": "https://registry.npmjs.org/rc/-/rc-1.2.8.tgz",
      "integrity": "sha512-y3bGgqKj3QBdxLbLkomlohkvsA8gdAiUQlSBJnBhfn+BPxg4bc62d8TcBW15wavDfgexCgccckhcZvywyQYPOw==",
      "license": "(BSD-2-Clause OR MIT OR Apache-2.0)",
      "dependencies": {
        "deep-extend": "^0.6.0",
        "ini": "~1.3.0",
        "minimist": "^1.2.0",
        "strip-json-comments": "~2.0.1"
      },
      "bin": {
        "rc": "cli.js"
      }
    },
    "node_modules/readable-stream": {
      "version": "3.6.2",
      "resolved": "https://registry.npmjs.org/readable-stream/-/readable-stream-3.6.2.tgz",
      "integrity": "sha512-9u/sniCrY3D5WdsERHzHE4G2YCXqoG5FTHUiCC4SIbr6XcLZBY05ya9EKjYek9O5xOAwjGq+1JdGBAS7Q9ScoA==",
      "license": "MIT",
      "dependencies": {
        "inherits": "^2.0.3",
        "string_decoder": "^1.1.1",
        "util-deprecate": "^1.0.1"
      },
      "engines": {
        "node": ">= 6"
      }
    },
    "node_modules/safe-buffer": {
      "version": "5.2.1",
      "resolved": "https://registry.npmjs.org/safe-buffer/-/safe-buffer-5.2.1.tgz",
      "integrity": "sha512-rp3So07KcdmmKbGvgaNxQSJr7bGVSVk5S9Eq1F+ppbRo70+YeaDxkw5Dd8NPN+GD6bjnYm2VuPuCXmpuYvmCXQ==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/feross"
        },
        {
          "type": "patreon",
          "url": "https://www.patreon.com/feross"
        },
        {
          "type": "consulting",
          "url": "https://feross.org/support"
        }
      ],
      "license": "MIT"
    },
    "node_modules/semver": {
      "version": "7.7.4",
      "resolved": "https://registry.npmjs.org/semver/-/semver-7.7.4.tgz",
      "integrity": "sha512-vFKC2IEtQnVhpT78h1Yp8wzwrf8CM+MzKMHGJZfBtzhZNycRFnXsHk6E5TxIkkMsgNS7mdX3AGB7x2QM2di4lA==",
      "license": "ISC",
      "bin": {
        "semver": "bin/semver.js"
      },
      "engines": {
        "node": ">=10"
      }
    },
    "node_modules/simple-concat": {
      "version": "1.0.1",
      "resolved": "https://registry.npmjs.org/simple-concat/-/simple-concat-1.0.1.tgz",
      "integrity": "sha512-cSFtAPtRhljv69IK0hTVZQ+OfE9nePi/rtJmw5UjHeVyVroEqJXP1sFztKUy1qU+xvz3u/sfYJLa947b7nAN2Q==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/feross"
        },
        {
          "type": "patreon",
          "url": "https://www.patreon.com/feross"
        },
        {
          "type": "consulting",
          "url": "https://feross.org/support"
        }
      ],
      "license": "MIT"
    },
    "node_modules/simple-get": {
      "version": "4.0.1",
      "resolved": "https://registry.npmjs.org/simple-get/-/simple-get-4.0.1.tgz",
      "integrity": "sha512-brv7p5WgH0jmQJr1ZDDfKDOSeWWg+OVypG99A/5vYGPqJ6pxiaHLy8nxtFjBA7oMa01ebA9gfh1uMCFqOuXxvA==",
      "funding": [
        {
          "type": "github",
          "url": "https://github.com/sponsors/feross"
        },
        {
          "type": "patreon",
          "url": "https://www.patreon.com/feross"
        },
        {
          "type": "consulting",
          "url": "https://feross.org/support"
        }
      ],
      "license": "MIT",
      "dependencies": {
        "decompress-response": "^6.0.0",
        "once": "^1.3.1",
        "simple-concat": "^1.0.0"
      }
    },
    "node_modules/string_decoder": {
      "version": "1.3.0",
      "resolved": "https://registry.npmjs.org/string_decoder/-/string_decoder-1.3.0.tgz",
      "integrity": "sha512-hkRX8U1WjJFd8LsDJ2yQ/wWWxaopEsABU1XfkM8A+j0+85JAGppt16cr1Whg6KIbb4okU6Mql6BOj+uup/wKeA==",
      "license": "MIT",
      "dependencies": {
        "safe-buffer": "~5.2.0"
      }
    },
    "node_modules/strip-json-comments": {
      "version": "2.0.1",
      "resolved": "https://registry.npmjs.org/strip-json-comments/-/strip-json-comments-2.0.1.tgz",
      "integrity": "sha512-4gB8na07fecVVkOI6Rs4e7T6NOTki5EmL7TUduTs6bu3EdnSycntVJ4re8kgZA+wx9IueI2Y11bfbgwtzuE0KQ==",
      "license": "MIT",
      "engines": {
        "node": ">=0.10.0"
      }
    },
    "node_modules/tar-fs": {
      "version": "2.1.4",
      "resolved": "https://registry.npmjs.org/tar-fs/-/tar-fs-2.1.4.tgz",
      "integrity": "sha512-mDAjwmZdh7LTT6pNleZ05Yt65HC3E+NiQzl672vQG38jIrehtJk/J3mNwIg+vShQPcLF/LV7CMnDW6vjj6sfYQ==",
      "license": "MIT",
      "dependencies": {
        "chownr": "^1.1.1",
        "mkdirp-classic": "^0.5.2",
        "pump": "^3.0.0",
        "tar-stream": "^2.1.4"
      }
    },
    "node_modules/tar-stream": {
      "version": "2.2.0",
      "resolved": "https://registry.npmjs.org/tar-stream/-/tar-stream-2.2.0.tgz",
      "integrity": "sha512-ujeqbceABgwMZxEJnk2HDY2DlnUZ+9oEcb1KzTVfYHio0UE6dG71n60d8D2I4qNvleWrrXpmjpt7vZeF1LnMZQ==",
      "license": "MIT",
      "dependencies": {
        "bl": "^4.0.3",
        "end-of-stream": "^1.4.1",
        "fs-constants": "^1.0.0",
        "inherits": "^2.0.3",
        "readable-stream": "^3.1.1"
      },
      "engines": {
        "node": ">=6"
      }
    },
    "node_modules/tunnel-agent": {
      "version": "0.6.0",
      "resolved": "https://registry.npmjs.org/tunnel-agent/-/tunnel-agent-0.6.0.tgz",
      "integrity": "sha512-McnNiV1l8RYeY8tBgEpuodCC1mLUdbSN+CYBL7kJsJNInOP8UjDDEwdk6Mw60vdLLrr5NHKZhMAOSrR2NZuQ+w==",
      "license": "Apache-2.0",
      "dependencies": {
        "safe-buffer": "^5.0.1"
      },
      "engines": {
        "node": "*"
      }
    },
    "node_modules/util-deprecate": {
      "version": "1.0.2",
      "resolved": "https://registry.npmjs.org/util-deprecate/-/util-deprecate-1.0.2.tgz",
      "integrity": "sha512-EPD5q1uXyFxJpCrLnCc1nHnq3gOa6DZBocAIiI2TaSCA7VCJ1UJDMagCzIkXNsUYfD1daK//LTEQ8xiIbrHtcw==",
      "license": "MIT"
    },
    "node_modules/wrappy": {
      "version": "1.0.2",
      "resolved": "https://registry.npmjs.org/wrappy/-/wrappy-1.0.2.tgz",
      "integrity": "sha512-l4Sp/DRseor9wL6EvV2+TuQn63dMkPjZ/sp9XkghTEbV9KlPS1xUsZ3u7/IQO4wxtcFB4bgpQPRcR3QCvezPcQ==",
      "license": "ISC"
    }
  }
}
JSON
  '';

  rebuiltNativeModules = buildNpmPackage {
    pname = "codex-native-modules";
    inherit version;
    src = nativeModulesSrc;

    npmDepsHash = "sha256-IBGwAGnZYnAHfciCDeKch6OGTif3tRZ0MQzEbffJCfg=";
    dontNpmBuild = true;
    npmRebuildFlags = [
      "better-sqlite3"
      "node-pty"
    ];

    nativeBuildInputs = [
      python3
      pkg-config
      gnumake
      gcc
    ];

    env = {
      npm_config_nodedir = "${electron_40.headers}";
      npm_config_build_from_source = "true";
    };

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -r node_modules "$out/"
      runHook postInstall
    '';
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Codex";
    exec = "codex-app %U";
    icon = pname;
    terminal = false;
    categories = [ "Development" "Utility" ];
  };
in
stdenv.mkDerivation {
  inherit pname version;

  src = codexSrc;
  dontUnpack = true;

  nativeBuildInputs = [
    copyDesktopItems
    nodePackages.asar
    nodejs_24
    python3
    pkg-config
    gnumake
    gcc
    binutils
    libicns
    unzip
  ];

  desktopItems = [ desktopItem ];

  installPhase = ''
    runHook preInstall

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

    archiveWorkDir="$TMPDIR/archive"
    mkdir -p "$archiveWorkDir"
    cd "$archiveWorkDir"

    unzip -q "$src" \
      "Codex.app/Contents/Resources/app.asar" \
      "Codex.app/Contents/Resources/app.asar.unpacked/*" \
      "Codex.app/Contents/Resources/electron.icns"

    test -f "Codex.app/Contents/Resources/app.asar"

    appDir="$TMPDIR/app"
    asar extract "Codex.app/Contents/Resources/app.asar" "$appDir"

    if [ -d "Codex.app/Contents/Resources/app.asar.unpacked" ]; then
      cp -r "Codex.app/Contents/Resources/app.asar.unpacked" "$appDir/app.asar.unpacked"
    fi

    rm -rf "$appDir/node_modules/better-sqlite3" "$appDir/node_modules/node-pty"
    cp -r "${rebuiltNativeModules}/node_modules/better-sqlite3" "$appDir/node_modules/"
    cp -r "${rebuiltNativeModules}/node_modules/node-pty" "$appDir/node_modules/"

    # Force a final native rebuild against Electron headers to avoid ABI drift.
    chmod -R u+w "$appDir/node_modules/better-sqlite3" "$appDir/node_modules/node-pty"
    pushd "$appDir" >/dev/null

    # Force fallback to local compilation even when host systems leak a global
    # prebuild-install binary into PATH (common on non-NixOS machines).
    mkdir -p "$TMPDIR/fakebin"
    cat > "$TMPDIR/fakebin/prebuild-install" <<'SH'
    #!/bin/sh
    exit 1
    SH
    chmod +x "$TMPDIR/fakebin/prebuild-install"
    export PATH="$TMPDIR/fakebin:$PATH"

    export npm_config_nodedir="${electron_40.headers}"
    export npm_config_runtime="electron"
    export npm_config_target="${electron_40.version}"
    export npm_config_disturl="https://electronjs.org/headers"
    export npm_config_build_from_source="true"
    export npm_config_offline="true"
    npm rebuild better-sqlite3 node-pty --foreground-scripts
    popd >/dev/null

    if [ -d "$appDir/app.asar.unpacked/node_modules" ]; then
      rm -rf "$appDir/app.asar.unpacked/node_modules/better-sqlite3" "$appDir/app.asar.unpacked/node_modules/node-pty"
      cp -r "$appDir/node_modules/better-sqlite3" "$appDir/app.asar.unpacked/node_modules/"
      cp -r "$appDir/node_modules/node-pty" "$appDir/app.asar.unpacked/node_modules/"
    fi

    rm -f "$appDir/native/sparkle.node"
    rm -f "$appDir/app.asar.unpacked/native/sparkle.node" || true

    # Install a desktop icon from the upstream .icns resource.
    if [ -f "Codex.app/Contents/Resources/electron.icns" ]; then
      iconWorkDir="$TMPDIR/icon"
      mkdir -p "$iconWorkDir"
      icns2png -x -o "$iconWorkDir" "Codex.app/Contents/Resources/electron.icns" >/dev/null || true

      for icon in "$iconWorkDir"/electron_*x*x32.png; do
        [ -f "$icon" ] || continue
        size="$(basename "$icon" | sed -E 's/^electron_([0-9]+)x([0-9]+)x32\.png$/\1x\2/')"
        mkdir -p "$out/share/icons/hicolor/$size/apps"
        cp "$icon" "$out/share/icons/hicolor/$size/apps/${pname}.png"
      done
    fi

    mkdir -p "$appDir/node_modules/electron-liquid-glass" "$appDir/node_modules/sparkle"

    cat > "$appDir/node_modules/electron-liquid-glass/package.json" <<'JSON'
    {"name":"electron-liquid-glass","version":"0.0.0","main":"index.js"}
    JSON

    cat > "$appDir/node_modules/electron-liquid-glass/index.js" <<'JS'
    const stub = {
      isGlassSupported: () => false,
      enable: () => {},
      disable: () => {},
      setOptions: () => {},
    };

    module.exports = stub;
    module.exports.default = stub;
    JS

    cat > "$appDir/node_modules/sparkle/package.json" <<'JSON'
    {"name":"sparkle","version":"0.0.0","main":"index.js"}
    JSON

    cat > "$appDir/node_modules/sparkle/index.js" <<'JS'
    module.exports = {
      init: () => {},
      checkForUpdates: () => {},
    };
    JS

    mkdir -p "$out/share/${pname}"
    cp -r "$appDir" "$out/share/${pname}/app"

    # Smoke-test native modules against the Electron runtime without starting UI.
    cat > "$TMPDIR/check-native.cjs" <<'JS'
    const fs = require("node:fs");
    const path = require("node:path");

    const appDir = process.argv[2];
    const checks = [
      path.join(appDir, "node_modules", "better-sqlite3"),
      path.join(appDir, "node_modules", "node-pty"),
      path.join(appDir, "app.asar.unpacked", "node_modules", "better-sqlite3"),
      path.join(appDir, "app.asar.unpacked", "node_modules", "node-pty"),
    ];

    for (const modPath of checks) {
      if (!fs.existsSync(modPath)) continue;
      // eslint-disable-next-line no-console
      console.log(`Checking native module: ''${modPath}`);
      // eslint-disable-next-line import/no-dynamic-require, global-require
      require(modPath);
    }
    JS

    ELECTRON_RUN_AS_NODE=1 "${electron_40}/bin/electron" "$TMPDIR/check-native.cjs" "$out/share/${pname}/app"

    # Guard against stale Node-ABI builds that crash on startup in Electron.
    for nativeNode in \
      "$out/share/${pname}/app/node_modules/better-sqlite3/build/Release/better_sqlite3.node" \
      "$out/share/${pname}/app/app.asar.unpacked/node_modules/better-sqlite3/build/Release/better_sqlite3.node"
    do
      if [ -f "$nativeNode" ] && nm -D "$nativeNode" | grep -q '_ZN2v811HandleScopeC1EPNS_7IsolateE'; then
        echo "error: incompatible better-sqlite3 native module ABI detected: $nativeNode" >&2
        exit 1
      fi
    done

    mkdir -p "$out/bin"
    cat > "$out/bin/codex-app" <<'EOF'
    #!@SHELL@
    set -euo pipefail

    APP_DIR="@APP_DIR@"

    export ELECTRON_RENDERER_URL="file://@APP_DIR@/webview/index.html"

    if [ -z "''${CODEX_CLI_PATH:-}" ] && command -v codex >/dev/null 2>&1; then
      export CODEX_CLI_PATH="$(command -v codex)"
    fi

    extra_args=()
    has_ozone_platform_flag=0
    for arg in "$@"; do
      case "$arg" in
        --ozone-platform|--ozone-platform=*)
          has_ozone_platform_flag=1
          ;;
      esac
    done

    # Default to x11 on Linux to improve compatibility on non-NixOS distros.
    if [ "$has_ozone_platform_flag" -eq 0 ]; then
      extra_args+=("--ozone-platform=''${CODEX_APP_OZONE_PLATFORM:-x11}")
    fi

    cd "@APP_DIR@"
    exec "@ELECTRON_BIN@" "$APP_DIR" --no-sandbox "''${extra_args[@]}" "$@"
    EOF

    substituteInPlace "$out/bin/codex-app" \
      --replace-fail "@SHELL@" "${stdenv.shell}" \
      --replace-fail "@APP_DIR@" "$out/share/${pname}/app" \
      --replace-fail "@ELECTRON_BIN@" "${electron_40}/bin/electron"

    chmod +x "$out/bin/codex-app"

    runHook postInstall
  '';

  postFixup = ''
    desktopFile="$out/share/applications/${pname}.desktop"
    iconFile="$out/share/icons/hicolor/512x512/apps/${pname}.png"

    if [ -f "$desktopFile" ] && [ -f "$iconFile" ]; then
      substituteInPlace "$desktopFile" \
        --replace-fail "Icon=${pname}" "Icon=$iconFile"
    fi
  '';

  meta = {
    description = "Codex desktop app repackaged for Linux from a versioned macOS release artifact";
    homepage = "https://openai.com";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "codex-app";
    platforms = [ "x86_64-linux" ];
  };

  passthru = {
    inherit updateScript;
  };
}
