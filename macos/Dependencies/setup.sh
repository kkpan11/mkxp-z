#!/usr/bin/env ruby

HOST = `clang -dumpmachine`.strip
ARCH = HOST[/x86_64|arm64/]

def run_build(arch)
    printf("====================================================\n")
    printf("Building all dependencies. This'll take a while.\n")

    if `xcodebuild -version`.scan(/Xcode (\d+)/)[0][0].to_i >= 12
        printf("Building libraries for Apple Silicon...\n")
        printf("====================================================\n")
        code = system("make everything -f arm64.make")
        return code if !code
    end
    printf("====================================================\n")
    printf("Building libraries for Intel...\n")
    printf("====================================================\n")
    code = (system("make everything -f x86_64.make"))
    return code if !code

    printf("====================================================\n")
    printf("Performing post-setup...\n")
    printf("====================================================\n")
    printf("Creating universal libraries ...\n")
    return system("./make_macuniversal.sh")
end

def fix_steam(libpath)
    # Don't need to do anything if it's already set to runpath
    return 0 if (`otool -L #{libpath}`[/@rpath/])
    printf("Patching Steamworks SDK...\n")
    # Remove 32-bit code from the binary
    if `lipo -info #{libpath}`[/i386/]
        return 1 if !system("lipo -remove i386 #{libpath} -o #{libpath}")
    end
    # Set the install name to runpath
    return 1 if !system("install_name_tool -id @rpath/libsteam_api.dylib #{libpath}")
    # Resign
    return (system("codesign -fs - #{libpath}") ? 0 : 1)
end

exitcode = run_build(ARCH) ? 0 : 1
exit(exitcode) if (exitcode != 0)

STEAM_LIB = "Frameworks/steam/sdk/redistributable_bin/osx/libsteam_api.dylib"
if File.exists?(STEAM_LIB)
    exitcode = fix_steam(STEAM_LIB)
end

printf("Done.\n\n")

exit(exitcode)
