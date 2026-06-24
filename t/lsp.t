use strict;
use warnings;

use File::Temp qw(tempdir);
use FindBin;
use Test::More;

sub run_lsp {
    my (@args) = @_;

    local $ENV{NO_COLOR} = 1;
    delete local $ENV{CLICOLOR_FORCE};
    return run_lsp_with_current_env(@args);
}

sub run_lsp_with_color {
    my (@args) = @_;

    delete local $ENV{NO_COLOR};
    local $ENV{CLICOLOR_FORCE} = 1;
    return run_lsp_with_current_env(@args);
}

sub run_lsp_with_current_env {
    my (@args) = @_;

    my $script = "$FindBin::Bin/../lsp";
    my $cmd = join ' ', map { shell_quote($_) } ($^X, $script, @args);
    my $output = `$cmd 2>&1`;
    my $exit = $? >> 8;

    return ($exit, $output);
}

sub shell_quote {
    my ($value) = @_;
    $value =~ s/'/'\\''/g;
    return "'$value'";
}

sub make_executable {
    my ($path) = @_;
    open my $fh, '>', $path or die "cannot create $path: $!";
    print {$fh} "#!/bin/sh\nexit 0\n";
    close $fh or die "cannot close $path: $!";
    chmod 0755, $path or die "cannot chmod $path: $!";
}

sub wait_for_process_marker {
    my ($pid, $marker) = @_;

    for (1 .. 50) {
        my $args = `ps -p $pid -o args= 2>/dev/null`;
        return 1 if defined $args && index($args, $marker) >= 0;
        select undef, undef, undef, 0.1;
    }

    return 0;
}

my $bin = tempdir(CLEANUP => 1);
make_executable("$bin/lsp-test-command");

{
    local $ENV{PATH} = $bin;
    my ($exit, $output) = run_lsp('lsp-test');

    is $exit, 0, 'default mode searches PATH commands';
    like $output, qr{\Q$bin/lsp-test-command\E}, 'default mode prints matching PATH command';
}

{
    local $ENV{PATH} = $bin;
    my ($exit, $output) = run_lsp('lsp-test', '/path');

    is $exit, 0, '/path explicitly searches PATH commands';
    like $output, qr{\Q$bin/lsp-test-command\E}, '/path prints matching PATH command';
}

{
    my $marker = 'lsp-ps-test-' . $$ . '-' . int rand 1_000_000;
    my $pid = fork();
    die 'fork failed' if !defined $pid;

    if ($pid == 0) {
        exec $^X, '-e', 'sleep 20', $marker;
        exit 127;
    }

    ok wait_for_process_marker($pid, $marker), 'test process marker is visible to ps';

    my ($exit, $output) = run_lsp($marker, '/ps');
    my ($color_exit, $color_output) = run_lsp_with_color($marker, '/ps');
    kill 'TERM', $pid;
    waitpid $pid, 0;

    is $exit, 0, '/ps searches running processes';
    like $output, qr/\Q$marker\E/, '/ps prints matching running process command';
    like $output, qr/\b$pid\b/, '/ps prints matching running process pid';
    like $output, qr/^\s*PID\s+COMMAND\s+CMDLINE$/m, '/ps prints a readable process table header';
    like $output, qr/^\s*\Q$pid\E\s+\S+\s+.*\Q$marker\E/m, '/ps aligns pid, command name, and command line';
    unlike $output, qr/\e\[[0-9;]+m/, '/ps does not print ANSI colors when color is disabled';
    unlike $output, qr/NO SUCH OPTION/, '/ps is accepted as an option';
    is $color_exit, 0, '/ps works when terminal colors are forced';
    like $color_output, qr/\e\[[0-9;]+m/, '/ps prints ANSI colors when terminal colors are enabled';
}

{
    my ($exit, $output) = run_lsp('lsp-test', '/path', '/ps');

    isnt $exit, 0, 'path and process modes are mutually exclusive';
    like $output, qr{Cannot combine /path and /ps}, 'mutually exclusive modes explain the conflict';
}

done_testing;
