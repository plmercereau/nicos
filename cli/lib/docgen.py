import click


class MarkdownFormatter(click.HelpFormatter):
    def __init__(self, bin_cmd=None):
        super().__init__()
        self.bin_cmd = bin_cmd
        self.is_command = False
        self.current_usage = []

    def write_heading(self, heading):
        super().write(f"{'':>{self.current_indent}}### {heading}\n")

    def section(self, heading):
        self.is_command = heading == "Commands"
        return super().section(heading)

    def write_usage(self, prog, args="", prefix=None):
        # print("USAGE", prog)
        self.current_usage = prog.split(" ")
        if self.bin_cmd:
            modified_prog = self.current_usage.copy()
            modified_prog[0] = self.bin_cmd
            prog = " ".join(modified_prog)
        self.write("### Usage\n\n")
        self.write("```bash\n")
        self.write(f"{prog} {args}\n")
        self.write("```\n")

    def write_dl(self, rows, col_max=30, col_spacing=2):
        if self.is_command:
            # print("COMMAND", rows, self.current_usage)
            anchor = "-".join(self.current_usage)
            self.write("|     |     |\n")
            self.write("| --- | --- |\n")
            for [command, description] in rows:
                self.write(f"| [{command}](#{anchor}-{command}) | {description} |\n")

        else:
            self.write("```\n")
            super().write_dl(rows, col_max, col_spacing)
            self.write("```\n")


def recurse(value, path=[], bin_cmd=None):
    new_path = path + [value.name]
    name = " ".join(new_path)
    context = click.Context(value, info_name=name)
    formatter = MarkdownFormatter(bin_cmd=bin_cmd)
    formatter.write(f"\n## {name}\n")
    value.format_help(context, formatter)
    result = formatter.getvalue() if not value.hidden else ""
    if isinstance(value, click.Group):
        for command in value.list_commands(context):
            result += recurse(value.get_command(context, command), new_path, bin_cmd)
    return result


@click.command(help="Generate documentation of the CLI", hidden=True)
@click.pass_context
@click.option(
    "--bin-cmd",
    default="nicos",
    help="Name of the binary to use in the documentation.",
)
def docgen(ctx, bin_cmd):
    main = ctx.find_root().command

    print(recurse(main, path=[], bin_cmd=bin_cmd))
