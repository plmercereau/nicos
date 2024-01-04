import click

# TODO ./cli/cli.py --docgen secrets user --help is not working yet
# TODO one big, fat recursive command to generate all the help


class MarkdownFormatter(click.HelpFormatter):
    def __init__(self, indent_increment=2, width=None, max_width=None):
        super().__init__(indent_increment, width, max_width)

    def write_heading(self, heading):
        super().write(f"{'':>{self.current_indent}}### {heading}\n")

    def write_usage(self, prog, args="", prefix=None):
        self.write("### Usage\n\n")
        self.write("```bash\n")
        super().write_usage(prog, args, "")
        self.write("```\n")

    def write_dl(self, rows, col_max=30, col_spacing=2):
        self.write("```\n")
        super().write_dl(rows, col_max, col_spacing)
        self.write("```\n")


def get_name(ctx):
    if not ctx.parent:
        return "nicos"
    # if (ctx.command.name == "main"):
    #     return "nicos"
    else:
        return f"{get_name(ctx.parent)} {ctx.command.name}"


def get_help_option(self, _):
    def show_custom_help(ctx, param, value):
        if not value or ctx.resilient_parsing:
            return
        root = ctx.find_root()
        docgen = root.params["docgen"]
        if docgen:
            root.info_name = "nix run github:plmercereau/nicos --"  # or "nicos"
            formatter = MarkdownFormatter()
            name = get_name(ctx)
            formatter.write(f"## {name}\n")
            ctx.command.format_usage(ctx, formatter)
            ctx.command.format_help_text(ctx, formatter)
            ctx.command.format_options(ctx, formatter)
            ctx.command.format_epilog(ctx, formatter)
            help = formatter.getvalue()
        else:
            help = ctx.get_help()
        click.echo(help)

        ctx.exit()

    return click.Option(
        ["--help"],
        is_flag=True,
        expose_value=False,
        callback=show_custom_help,
        help="Show this message and exit.",
    )


class CustomGroup(click.Group):
    def get_help_option(self, ctx):
        return get_help_option(self, ctx)

    def add_command(self, cmd, name=None):
        cmd.get_help_option = lambda ctx: get_help_option(cmd, ctx)
        super().add_command(cmd, name)
