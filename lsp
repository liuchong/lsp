#!/usr/bin/perl

use strict;
use warnings;
use Cwd qw(getcwd);
use Fcntl ':mode';
use Term::ANSIColor qw(colored);

our $COLOR_ENABLED = 0;
our %ANSI_BY_KEY;
our %ANSI_BY_EXT;

sub print_help {
    print "HELP FOR \"lsp\"\n"
        . "\t\tFind some command matched the given words.\n"
        . "Usage:\n"
        . "\t\tlsp [cmd cdm mcd ...] [OPTIONS]\n"
        . "OPTIONS:\n"
        . "\t\tExcept -h and --help which will print"
        . " this help text,others will headed\n\t\tby \"/\",whi"
        . "ch symbol will not appear in a file name without the"
        . " path of\n\t\tparents directorys with \"/\".\n"
        . "\n"
        . "/P\t\tOnly search the path what you given behind.\n"
        . "/A\t\tAppend what you given to the search path.\n"
        . "/s\t\tAlso search /sbin,/usr/sbin,/usr/local/sbin.\n"
        . "/p\t\tPrint PATH,also print the path after the sbins"
        . " added if the\n\t\toption /s was given.\n"
        . "/e\t\tExactly match will be printed while others not.\n"
        . "/l\t\tPrint matches in a pure Perl long format.\n"
        . "/h\t\t\"/h\" take place of \"-h\" as above.\n"
        . "//help\t\t\"//help\"take place of \"--help\" as above.\n"
        . "-h,--help\tDisplay this help list.\n";
    exit;
}

sub cprint {
    my ($text, $color) = @_;

    if ($color && $COLOR_ENABLED) {
        print colored($text, $color);
    } else {
        print $text;
    }
}

sub terminal_supports_color {
    return 0 if exists $ENV{'NO_COLOR'} && $ENV{'NO_COLOR'} ne '';
    return 1 if defined $ENV{'CLICOLOR_FORCE'} && $ENV{'CLICOLOR_FORCE'} ne '0';
    return 0 if defined $ENV{'CLICOLOR'} && $ENV{'CLICOLOR'} eq '0';
    return 0 if !-t STDOUT;

    my $term = $ENV{'TERM'} || '';
    return 1 if defined $ENV{'COLORTERM'} && $ENV{'COLORTERM'} ne '';
    return 0 if $term eq '' || $term eq 'dumb';

    return 1;
}

sub default_ls_colors {
    return (
        bd => '01;33',
        cd => '01;33',
        di => '01;34',
        ex => '01;32',
        ln => '01;36',
        or => '01;31',
        ow => '34;42',
        pi => '33',
        sg => '30;43',
        so => '01;35',
        st => '37;44',
        su => '37;41',
        tw => '30;42',
        '*.7z'  => '01;31',
        '*.bz2' => '01;31',
        '*.gz'  => '01;31',
        '*.tar' => '01;31',
        '*.tbz' => '01;31',
        '*.tgz' => '01;31',
        '*.xz'  => '01;31',
        '*.zip' => '01;31',
        '*.gif' => '01;35',
        '*.jpeg' => '01;35',
        '*.jpg' => '01;35',
        '*.png' => '01;35',
        '*.svg' => '01;35',
        '*.webp' => '01;35',
        '*.mov' => '01;35',
        '*.mp4' => '01;35',
        '*.webm' => '01;35',
        '*.flac' => '00;36',
        '*.m4a' => '00;36',
        '*.mp3' => '00;36',
        '*.ogg' => '00;36',
        '*.wav' => '00;36',
    );
}

sub parse_gnu_ls_colors {
    my ($value) = @_;
    my (%by_key, %by_ext);

    for my $item (split /:/, ($value || '')) {
        next if $item !~ /\A([^=]+)=(.*)\z/;

        my ($key, $ansi) = ($1, $2);
        next if $ansi eq '';
        next if $ansi !~ /\A[0-9;]+\z/;

        if ($key =~ /\A\*(.+)\z/) {
            $by_ext{lc $1} = $ansi;
        } else {
            $by_key{$key} = $ansi;
        }
    }

    return (\%by_key, \%by_ext);
}

sub lscolors_code_to_ansi {
    my ($char, $is_background) = @_;
    return if !defined $char || $char eq 'x' || $char eq 'X';

    my $lower = lc $char;
    my %base = (
        a => 0,
        b => 1,
        c => 2,
        d => 3,
        e => 4,
        f => 5,
        g => 6,
        h => 7,
    );
    return if !exists $base{$lower};

    my $code = ($is_background ? 40 : 30) + $base{$lower};
    return $is_background || $char eq $lower ? "$code" : "01;$code";
}

sub parse_bsd_lscolors {
    my ($value) = @_;
    my %by_key;
    my @keys = qw(di ln so pi ex bd cd su sg tw ow);
    $value = substr(($value || '') . ('x' x 22), 0, 22);

    for my $i (0 .. $#keys) {
        my $fg = substr $value, $i * 2, 1;
        my $bg = substr $value, $i * 2 + 1, 1;
        my @ansi = grep { defined && $_ ne '' } (
            lscolors_code_to_ansi($fg, 0),
            lscolors_code_to_ansi($bg, 1),
        );
        $by_key{$keys[$i]} = join ';', @ansi if @ansi;
    }

    return %by_key;
}

sub setup_colors {
    my (%by_key, %by_ext);

    my %defaults = default_ls_colors();
    for my $key (keys %defaults) {
        if ($key =~ /\A\*(.+)\z/) {
            $by_ext{lc $1} = $defaults{$key};
        } else {
            $by_key{$key} = $defaults{$key};
        }
    }

    if (defined $ENV{'LSCOLORS'} && !defined $ENV{'LS_COLORS'}) {
        my %bsd_colors = parse_bsd_lscolors($ENV{'LSCOLORS'});
        @by_key{keys %bsd_colors} = values %bsd_colors;
    }

    if (defined $ENV{'LS_COLORS'}) {
        my ($gnu_keys, $gnu_exts) = parse_gnu_ls_colors($ENV{'LS_COLORS'});
        @by_key{keys %{$gnu_keys}} = values %{$gnu_keys};
        @by_ext{keys %{$gnu_exts}} = values %{$gnu_exts};
    }

    return (\%by_key, \%by_ext);
}

sub ansi_wrap {
    my ($text, $ansi) = @_;
    return $text if !$COLOR_ENABLED || !defined $ansi || $ansi eq '' || $ansi eq '00' || $ansi eq '0';

    return "\e[${ansi}m$text\e[0m";
}

sub clean_path {
    my ($path) = @_;
    return $path if !defined $path || $path eq '';

    my $is_absolute = $path =~ m{^/};
    my @parts;

    for my $part (split m{/+}, $path) {
        next if $part eq '' || $part eq '.';

        if ($part eq '..') {
            if (@parts && $parts[-1] ne '..') {
                pop @parts;
            } elsif (!$is_absolute) {
                push @parts, $part;
            }
            next;
        }

        push @parts, $part;
    }

    my $cleaned = join '/', @parts;
    return $is_absolute ? "/$cleaned" : ($cleaned || '.');
}

sub normalize_search_path {
    my ($path, $pwd) = @_;
    return if !defined $path || $path eq '';

    $path = $pwd if $path eq '.';
    $path = "$pwd/$path" if $path !~ m{^/};
    $path =~ s{/+\z}{};

    return $path eq '' ? '/' : $path;
}

sub file_type_char {
    my ($mode) = @_;

    return 'l' if S_ISLNK($mode);
    return 'd' if S_ISDIR($mode);
    return 'c' if S_ISCHR($mode);
    return 'b' if S_ISBLK($mode);
    return 'p' if S_ISFIFO($mode);
    return 's' if S_ISSOCK($mode);
    return '-';
}

sub permission_char {
    my ($mode, $bit, $special_bit, $regular_char, $special_char, $missing_special_char) = @_;

    my $has_bit = $mode & $bit;
    my $has_special = $mode & $special_bit;

    return $special_char if $has_bit && $has_special;
    return $missing_special_char if !$has_bit && $has_special;
    return $regular_char if $has_bit;
    return '-';
}

sub format_permissions {
    my ($mode) = @_;

    return file_type_char($mode)
        . (($mode & S_IRUSR) ? 'r' : '-')
        . (($mode & S_IWUSR) ? 'w' : '-')
        . permission_char($mode, S_IXUSR, S_ISUID, 'x', 's', 'S')
        . (($mode & S_IRGRP) ? 'r' : '-')
        . (($mode & S_IWGRP) ? 'w' : '-')
        . permission_char($mode, S_IXGRP, S_ISGID, 'x', 's', 'S')
        . (($mode & S_IROTH) ? 'r' : '-')
        . (($mode & S_IWOTH) ? 'w' : '-')
        . permission_char($mode, S_IXOTH, S_ISVTX, 'x', 't', 'T');
}

sub format_time {
    my ($epoch) = @_;
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my (undef, $min, $hour, $mday, $mon) = localtime $epoch;

    return sprintf "%s %2d %02d:%02d", $months[$mon], $mday, $hour, $min;
}

sub file_type_description {
    my ($path) = @_;
    my @stat = lstat $path;
    return "unreadable\n" if !@stat;

    my $mode = $stat[2];
    return "symbolic link\n" if S_ISLNK($mode);
    return "directory\n" if S_ISDIR($mode);
    return "executable file\n" if S_ISREG($mode) && -x $path;
    return "regular file\n" if S_ISREG($mode);
    return "character special file\n" if S_ISCHR($mode);
    return "block special file\n" if S_ISBLK($mode);
    return "fifo\n" if S_ISFIFO($mode);
    return "socket\n" if S_ISSOCK($mode);
    return "unknown\n";
}

sub color_key_for_path {
    my ($path) = @_;
    my @stat = lstat $path;
    return 'mi' if !@stat;

    my $mode = $stat[2];

    if (S_ISLNK($mode)) {
        return -e $path ? 'ln' : 'or';
    }

    if (S_ISDIR($mode)) {
        return 'tw' if ($mode & S_IWOTH) && ($mode & S_ISVTX);
        return 'ow' if $mode & S_IWOTH;
        return 'st' if $mode & S_ISVTX;
        return 'di';
    }

    return 'pi' if S_ISFIFO($mode);
    return 'so' if S_ISSOCK($mode);
    return 'bd' if S_ISBLK($mode);
    return 'cd' if S_ISCHR($mode);
    return 'su' if S_ISREG($mode) && ($mode & S_ISUID);
    return 'sg' if S_ISREG($mode) && ($mode & S_ISGID);
    return 'ex' if S_ISREG($mode) && -x $path;

    return '';
}

sub extension_color_for_path {
    my ($path) = @_;
    my $name = lc $path;

    for my $suffix (sort { length($b) <=> length($a) } keys %ANSI_BY_EXT) {
        return $ANSI_BY_EXT{$suffix} if substr($name, -length($suffix)) eq $suffix;
    }

    return;
}

sub color_for_path {
    my ($path) = @_;
    my $key = color_key_for_path($path);

    return $ANSI_BY_KEY{$key} if $key && exists $ANSI_BY_KEY{$key};
    return extension_color_for_path($path);
}

sub display_path {
    my ($display, $path) = @_;

    return ansi_wrap($display, color_for_path($path));
}

sub resolve_link_target_path {
    my ($path, $target) = @_;
    return if !defined $target;
    return clean_path($target) if $target =~ m{^/};

    my $dir = $path;
    $dir =~ s{/[^/]+\z}{/};
    return clean_path("$dir$target");
}

sub print_match_long {
    my ($path) = @_;
    my @stat = lstat $path;

    if (!@stat) {
        warn "**ERROR** $path $!\n";
        return;
    }

    my ($mode, $nlink, $uid, $gid, $size, $mtime) = @stat[2, 3, 4, 5, 7, 9];
    my $owner = getpwuid $uid;
    my $group = getgrgid $gid;
    $owner = $uid if !defined $owner;
    $group = $gid if !defined $group;

    printf "%s %3d %-8s %-8s %8d %s %s",
        format_permissions($mode),
        $nlink,
        $owner,
        $group,
        $size,
        format_time($mtime),
        display_path($path, $path);

    my $target = readlink $path if S_ISLNK($mode);
    if (defined $target) {
        my $target_path = resolve_link_target_path($path, $target);
        print " -> ";
        print display_path($target, $target_path);
    }
    print "\n";
}

sub print_match {
    my ($dir_name, $file_name, $long_format) = @_;
    my $path = "$dir_name/$file_name";

    if ($long_format) {
        print_match_long($path);
    } else {
        print display_path($path, $path);
        print " @" if -l $path;
        print " /" if -d $path;
        print " *" if -x $path;
        print "\n";
    }
}

sub find_ls {
    my ($dir_name, $wanted_name, $exact_only, $long_format) = @_;
    return (0, 0) if !$dir_name || !defined $wanted_name;

    my $dir_handle;
    if (!opendir $dir_handle, $dir_name) {
        warn "**ERROR** $dir_name $!\n";
        return (0, 0);
    }

    my $matches = 0;
    my $printed = 0;

    while (defined(my $file_name = readdir $dir_handle)) {
        next if index($file_name, $wanted_name) == -1;

        ++$matches;
        if (!$exact_only) {
            print_match($dir_name, $file_name, $long_format);
            ++$printed;
        }
    }

    closedir $dir_handle;

    if (!$exact_only && $printed) {
        print "Above is $printed matching in [";
        cprint("$dir_name/", "blue");
        print "]\n";
        print "^^^^^\n";
    }

    return ($matches, -e "$dir_name/$wanted_name" ? 1 : 0);
}

sub resolve_symlink_chain {
    my ($path) = @_;
    my @targets;
    my %seen;

    while (-l $path) {
        last if $seen{$path}++;

        my $target = readlink $path;
        last if !defined $target;

        if ($target !~ m{^/}) {
            my $dir = $path;
            $dir =~ s{/[^/]+\z}{/};
            $target = "$dir$target";
        }

        $target = clean_path($target);
        push @targets, $target;
        $path = $target;
    }

    return ($path, @targets);
}

sub is_runnable_command {
    my ($path) = @_;
    return -f $path && -x $path;
}

($COLOR_ENABLED, my $color_by_key, my $color_by_ext) = (
    terminal_supports_color(),
    setup_colors(),
);
%ANSI_BY_KEY = %{$color_by_key};
%ANSI_BY_EXT = %{$color_by_ext};

my %cmds_hash;
my @cmds;
my @extra_paths;
my ($mark_P, $mark_A, $mark_s, $mark_e, $mark_l, $mark_p);

for my $arg (@ARGV) {
    if (!$mark_P && !$mark_A) {
        if ($arg =~ m{^/}) {
            if ($arg eq '/P') {
                $mark_P = 1;
            } elsif ($arg eq '/A') {
                $mark_A = 1;
            } elsif ($arg eq '/s') {
                $mark_s = 1;
            } elsif ($arg eq '/e') {
                $mark_e = 1;
            } elsif ($arg eq '/l') {
                $mark_l = 1;
            } elsif ($arg eq '/p') {
                $mark_p = 1;
            } elsif ($arg eq '/h' || $arg eq '//help') {
                print_help();
            } else {
                print "NO SUCH OPTION: $arg\n\n";
                print_help();
            }
        } elsif ($arg eq '-h' || $arg eq '--help') {
            print_help();
        } else {
            push @cmds, $arg if !$cmds_hash{$arg};
            ++$cmds_hash{$arg};
        }
    } else {
        push @extra_paths, $arg;
    }
}

my @search_paths = @extra_paths;
if (!$mark_P) {
    push @search_paths, split /:/, ($ENV{'PATH'} || '');
    unshift @search_paths, qw(/sbin /usr/sbin /usr/local/sbin) if $mark_s;
}

my $cur_path = join ':', @search_paths;
if ($mark_p || !@ARGV) {
    print "********\n" if @ARGV;
    print ($ENV{'PATH'} || '');
    print "\n";
    print "********\n$cur_path\n" if $mark_s;
    print "********\n" if @ARGV;
}

my $pwd = $ENV{'PWD'} || getcwd();
my $cmds_left = scalar @cmds;

for my $cmd (@cmds) {
    print "========$cmd========\n" if @cmds > 1;
    print "YOU ENTERED $cmds_hash{$cmd} \"$cmd\"s,BUT ONLY USE ONCE:\n"
        if $cmds_hash{$cmd} > 1 && (@cmds > 1 || !$mark_e);

    my %dir_hash;
    my $counter = 0;
    my @exact_matches;

    for my $path (@search_paths) {
        my $this_path = normalize_search_path($path, $pwd);
        next if !defined $this_path;
        next if ++$dir_hash{$this_path} > 1;

        my ($matches, $exact_match) = find_ls($this_path, $cmd, $mark_e, $mark_l);
        $counter += $matches;
        push @exact_matches, $this_path if $exact_match;
    }

    if ($counter) {
        print "--------\n^_^ FINDED $counter MATCHING \"$cmd\"! ^_^\n"
            if !$mark_e;
    } else {
        print "--------\n!!!! NONE MATCHING \"$cmd\" !!!!\n";
    }

    my $using_cmd;
    for my $path (@exact_matches) {
        if (!$mark_e) {
            cprint("FIND AN EXACT ONE IN [", "bold");
            cprint("$path/", "bold blue");
            cprint("]:\n", "bold");
        } else {
            print "[$path]:\n";
        }

        my $exact_cmd = "$path/$cmd";
        $using_cmd = $exact_cmd
            if !defined $using_cmd && is_runnable_command($exact_cmd);

        if ($mark_l) {
            print_match_long($exact_cmd);
        } else {
            print display_path($exact_cmd, $exact_cmd);
        }
        my (undef, @symlink_targets) = resolve_symlink_chain($exact_cmd);
        for my $target (@symlink_targets) {
            if ($mark_l) {
                print_match_long($target);
            } else {
                print " -> ";
                print display_path($target, $target);
                print "\n";
                print display_path($target, $target);
            }
        }
        print "\n" if !$mark_l;
    }

    if ($using_cmd) {
        print "You Are Using:\n";
        if ($mark_l) {
            print_match_long($using_cmd);
            print "FILE TYPE : ";
            print file_type_description($using_cmd);
        } else {
            print display_path($using_cmd, $using_cmd);
            print "\n";
        }
    }

    --$cmds_left;
    print "\n" if $cmds_left > 0;
}
