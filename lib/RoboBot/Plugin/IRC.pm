package RoboBot::Plugin::IRC;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

extends 'RoboBot::Plugin';

=head1 irc

Provides a variety of functions for performing IRC-related actions like channel
topics, oper promotion/demotion, etc.

=cut

has '+name' => (
    default => 'IRC',
);

has '+description' => (
    default => 'Provides a variety of functions for performing IRC-related actions like channel topics, oper promotion/demotion, etc.',
);

=head2 topic

=head3 Description

When a new topic string is given, changes the channel\'s topic to that string. In all uses, returns the channel topic as a string.

=head3 Usage

[<new topic>]

=head3 Examples

    (topic "Super Awesome Channel Fun Times")

=cut

has '+commands' => (
    default => sub {{
        'topic' => { method      => 'channel_topic',
                     description => 'When a new topic string is given, changes the channel\'s topic to that string. In all uses, returns the channel topic as a string.',
                     usage       => '["<new topic>"]' },
    }},
);

sub channel_topic {
    my ($self, $message, $command, $rpl, $new_topic) = @_;

    return unless $message->has_channel;

    # TODO: Needs to delegate to protocol-specific Network plugin to obtain
    #       channel topic.
    my $channel_name = '#' . $message->channel->name;

    if (defined $new_topic) {
        $self->bot->irc->yield( topic => '#' . $channel_name, $new_topic );
    }

    return $self->bot->irc->yield( topic => $channel_name );
}

__PACKAGE__->meta->make_immutable;

1;
