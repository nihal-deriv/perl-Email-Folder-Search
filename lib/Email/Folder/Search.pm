package Email::Folder::Search;

# ABSTRACT: wait and fetch search from mailbox file

=head1 NAME

Email::Folder::Search

=head1 DESCRIPTION

Search email from mailbox file. This module is mainly to test that the emails are received or not.

=head1 SYNOPSIS

    use Email::Folder::Search;
    my $folder = Email::Folder::Search->new('/var/spool/mbox');
    my %msg = $folder->get_email_by_address_subject(email => 'hello@test.com', subject => qr/this is a subject/);
    $folder->clear();

=cut

=head1 Methods

=cut

use strict;
use warnings;
use NEXT;
use Email::Folder;
use Encode qw(decode);
use Scalar::Util qw(blessed);
use base 'Email::Folder';

our $VERSION = '0.01';

=head2 new($folder, %options)

takes the name of a folder, and a hash of options

options:

=over

=item timeout

The seconds that get_email_by_address_subject will wait if the email cannot be found.

=back

=cut

sub new {
    my $class       = shift;
    my $folder_path = shift // '/tmp/default.mailbox';
    my %options     = @_;
    my $self        = $class->NEXT::new($folder_path, %options);
    $self->{folder_path} = $folder_path;
    $self->{timeout} //= 3;
    return $self;
}

=head2 search(email => $email, subject => qr/the subject/);

get emails with receiver address and subject(regexp). Return an array of messages which are hashref.

    my $msgs = search(email => 'hello@test.com', subject => qr/this is a subject/);

=cut

sub search {
    my $self = shift;
    my %cond = @_;

    die 'Need email address and subject regexp' unless $cond{email} && $cond{subject} && ref($cond{subject}) eq 'Regexp';

    my $email          = $cond{email};
    my $subject_regexp = $cond{subject};

    my @msgs;

    my $found = 0;
    #mailbox maybe late, so we wait 3 seconds
    WAIT: for (0 .. $self->{timeout}) {
        MSG: while (my $tmsg = $self->next_message) {
            my $address = $tmsg->header('To');
            #my $address = $to[0]->address();
            my $subject = $tmsg->header('Subject');
            if ($subject =~ /=\?UTF\-8/) {
                $subject = decode('MIME-Header', $subject);
            }

            if ($address eq $email && $subject =~ $subject_regexp) {
                my %msg;
                $msg{body}    = $tmsg->body;
                $msg{address} = $address;
                $msg{subject} = $subject;
                push @msgs, \%msg;
                $found = 1;
            }
        }
        last WAIT if $found;
        # reset reader
        $self->reset;
        sleep 1;
    }
    return @msgs;
}

sub reset {
    my $self         = shift;
    my $reader_class = blessed($self->{_folder});
    delete $self->{_folder};
    $self->{_folder} = $reader_class->new($self->{folder_path}, %$self);
}

=head2 clear

clear the content of mailbox

=cut

sub clear {
    my $self = shift;
    my $type = blessed($self->{_folder}) // '';

    $self->reset;

    if ($type eq 'Email::Folder::Mbox') {
        truncate $self->{folder_path}, 0 // die "Cannot clear mailbox $self->{folder_path}\n";
    } else {
        die "Sorry, I can only clear the mailbox with the type Mbox\n";
    }

    return;
}

=head1 SEE ALSO

L<Email::Folder>

=cut

1;

