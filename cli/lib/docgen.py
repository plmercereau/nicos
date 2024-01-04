import click


def escape_markdown(text):
    replacements = {
        "<": "&lt;",
        ">": "&gt;",
    }
    for char, html_code in replacements.items():
        text = text.replace(char, html_code)
    return text


class MarkdownFormatter(click.HelpFormatter):
    def __init__(self, bin_cmd=None):
        super().__init__()
        self.bin_cmd = bin_cmd
        self.is_command = False
        self.current_usage = []

    def write_heading(self, heading):
        self.write(f"\n")

    def write_usage(self, prog, args="", prefix=None):
        """Usage, without the description"""
        self.current_usage = prog.split(" ")
        if self.bin_cmd:
            modified_prog = self.current_usage.copy()
            modified_prog[0] = self.bin_cmd
            prog = " ".join(modified_prog)
        self.write("```bash\n")
        self.write(f"{prog} {args}\n")
        self.write("```\n")

    def section(self, heading):
        self.is_command = heading == "Commands"
        return super().section(heading)

    def write_dl(self, rows, col_max=30, col_spacing=2):
        if self.is_command:
            self.write(f'<ParamField path="Commands">\n')
            anchor = "-".join(self.current_usage)
            self.write("|     |     |\n")
            self.write("| --- | --- |\n")
            for [command, description] in rows:
                command = escape_markdown(command)
                description = escape_markdown(description)
                self.write(f"| [{command}](#{anchor}-{command}) | {description} |\n")
            self.write("</ParamField>\n")
        else:
            self.write(f'<ParamField path="Options">\n')
            self.write("|     |     |\n")
            self.write("| --- | --- |\n")
            for [option, description] in rows:
                self.write(
                    "| `%s` | %s |\n"
                    % (
                        option.replace("|", "\\|"),
                        escape_markdown(description),
                    )
                )
                pass
            self.write("</ParamField>\n")


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
