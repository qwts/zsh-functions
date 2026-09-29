class ZshFunctions < Formula
  desc "Common zsh shell functions"
  homepage "https://github.com/qwts/zsh-functions"
  url "git@github.com:qwts/zsh-functions.git",
      tag:      "v0.2.0",
      revision: "29e7e99ac8649bffc643bd9c43c05f4ef06add83"
  version "0.2.0"
  head "git@github.com:qwts/zsh-functions.git", branch: "main"

  uses_from_macos "zsh"

  def install
    (share/"zsh-functions").mkpath
    (share/"zsh-functions").install Dir["functions/*"]
    bin.install "bin/zsh-profile"

    # ENG-0055 skill bundle, from v0.2.0 on: zsh-profile reads VERSION and
    # the skill from libexec, and skill-path reports the source commit.
    return unless File.exist?("VERSION")

    libexec.install "VERSION"
    (libexec/"skills").install "skills/zsh-functions"
    (libexec/"RELEASE_COMMIT").write "#{active_spec.specs[:revision] || "unknown"}\n"
  end

  def caveats
    <<~EOS
      Add the functions directory to your fpath in ~/.zshrc:
        fpath=("#{HOMEBREW_PREFIX}/share/zsh-functions" $fpath)
    EOS
  end

  test do
    Dir[share/"zsh-functions/*"].each do |f|
      system "zsh", "-n", f
    end
    assert_equal version.to_s, shell_output("#{bin}/zsh-profile --version").strip if (libexec/"VERSION").exist? && !version.head?
  end
end
