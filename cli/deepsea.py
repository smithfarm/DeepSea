# -*- coding: utf-8 -*-
"""
DeepSea CLI
"""
from __future__ import absolute_import
from __future__ import print_function

import logging.config
import logging
import os
import signal
import sys
import time
import click

import pkg_resources

from .config import Config
from .common import PrettyPrinter as PP
from .common import requires_root_privileges
from .monitor import Monitor
from .monitors.terminal_outputter import StepListPrinter, SimplePrinter
from .stage_executor import run_stage
from .stage_parser import SLSParser, SaltState, SaltRunner, SaltModule


def _setup_logging():
    """
    Logging configuration
    """
    if Config.LOG_LEVEL == "silent":
        return

    logging.config.dictConfig({
        'version': 1,
        'disable_existing_loggers': False,
        'formatters': {
            'standard': {
                'format': '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
            },
        },
        'handlers': {
            'file': {
                'level': Config.LOG_LEVEL.upper(),
                'filename': Config.LOG_FILE_PATH,
                'class': 'logging.FileHandler',
                'formatter': 'standard'
            },
        },
        'loggers': {
            '': {
                'handlers': ['file'],
                'level': Config.LOG_LEVEL.upper(),
                'propagate': True,
            }
        }
    })


def _run_monitor(show_state_steps, show_dynamic_steps, simple_output):
    """
    Run the DeepSea stage monitor and progress visualizer
    """
    mon = Monitor(show_state_steps, show_dynamic_steps)
    listener = SimplePrinter() if simple_output else StepListPrinter()
    mon.add_listener(listener)

    logger = logging.getLogger(__name__)

    # pylint: disable=W0613
    def sigint_handler(*args):
        """
        SIGINT signal handler
        """
        logger.debug("SIGINT, calling monitor.stop()")
        if not simple_output:
            PP.pl_bold("\x1b[2K\rShutting down...")
        else:
            PP.println("Shutting down...")
        PP.println()
        mon.stop()

    signal.signal(signal.SIGINT, sigint_handler)

    if not simple_output:
        os.system('clear')
        PP.println("Use Ctrl+C to stop the monitor")
        PP.p_bold("Initializing DeepSea progess monitor...")
    else:
        PP.println("Use Ctrl+C to stop the monitor")
        PP.print("Initializing DeepSea progess monitor...")

    mon.start()
    if not simple_output:
        PP.pl_bold(" done.")
    else:
        PP.println(" done")

    PP.println()
    if sys.version_info > (3, 0):
        logger.debug("Python 3: blocking main thread on join()")
        mon.wait_to_finish()
    else:
        logger.debug("Python 2: polling for monitor.is_running() %s", mon.is_running())
        while mon.is_running():
            time.sleep(2)
        mon.wait_to_finish()


def _validate_stage_file_exists(stage_name):
    """
    Verifies if the stage file corresponding to the stage_name arg really exists
    """
    # check if stage exists
    stage_file = "/srv/salt/{}".format(stage_name.replace('.', '/'))
    if not os.path.exists(stage_file) and not os.path.exists("{}.sls".format(stage_file)):
        PP.println("{}: Stage {} does not exist".format(PP.red("ERROR"),
                                                        PP.cyan(stage_name)))
        sys.exit(1)


def _run_show_stage_steps(stage_name, hide_state_steps, only_visible_steps, use_cache):
    """
    Runs stage parser and prints the list of steps
    """
    _validate_stage_file_exists(stage_name)

    PP.p_header("Parsing stage: {}".format(stage_name))
    steps, _ = SLSParser.parse_state_steps(stage_name, hide_state_steps, only_visible_steps,
                                           use_cache)
    print()
    PP.p_bold("List of steps for stage {}:".format(stage_name))
    print()
    state_count = 1
    sub_state_count = 1
    step_order_map = {}
    for step in steps:
        state_count_str = "{:<2}".format(state_count)
        sub_state_count_str = "{:4}{:>2}.{:<2}".format('', state_count-1, sub_state_count)
        if isinstance(step, SaltState):
            target_str = "{:30}".format(step.target)
            print("{}: [{}] {} on_success={} on_fail={}"
                  .format(PP.bold(state_count_str),
                          PP.magenta(target_str),
                          PP.green("State({})".format(step.state)),
                          [step_order_map[s.desc] for s in step.on_success_deps],
                          [step_order_map[s.desc] for s in step.on_fail_deps]))
            step_order_map[step.desc] = str(state_count)
            state_count += 1
            sub_state_count = 1
        elif isinstance(step, SaltRunner):
            target_str = "{:30}".format('master')
            print("{}: [{}] {} on_success={} on_fail={}"
                  .format(PP.bold(state_count_str),
                          PP.magenta(target_str),
                          PP.blue("Runner({})".format(step.fun)),
                          [step_order_map[s.desc] for s in step.on_success_deps],
                          [step_order_map[s.desc] for s in step.on_fail_deps]))
            step_order_map[step.desc] = str(state_count)
            state_count += 1
        elif isinstance(step, SaltModule):
            print("{}:{:26} {} on_success={} on_fail={}"
                  .format(PP.bold(sub_state_count_str), '',
                          PP.cyan("Module({})".format(step.fun)),
                          [step_order_map[s.desc] for s in step.on_success_deps],
                          [step_order_map[s.desc] for s in step.on_fail_deps]))
            step_order_map[step.desc] = "{}.{}".format(state_count-1, sub_state_count)
            sub_state_count += 1
        else:  # SaltBuiltIn
            step_str = "BuiltIn({})".format(step.fun)
            if step.fun in ['file.managed', 'file']:
                step_str = "BuiltIn({}, {})".format(step.fun, step.desc)
            elif step.fun in ['service.running', 'cmd.run']:
                arg = step.desc
                if 'name' in step.args:
                    arg = step.args['name']
                step_str = "BuiltIn({}, {})".format(step.fun, arg)
            elif step.fun in ['pkg.latest', 'pkg.installed']:
                arg = step.desc
                if 'name' in step.args:
                    arg = step.args['name']
                elif 'pkgs' in step.args:
                    arg = step.args['pkgs']
                step_str = "BuiltIn({}, {})".format(step.fun, arg)

            print("{}:{:26} {} on_success={} on_fail={}"
                  .format(PP.bold(sub_state_count_str), '',
                          PP.yellow(step_str),
                          [step_order_map[s.desc] for s in step.on_success_deps],
                          [step_order_map[s.desc] for s in step.on_fail_deps]))
            step_order_map[step.desc] = "{}.{}".format(state_count-1, sub_state_count)
            sub_state_count += 1
    print()
    PP.p_bold("Total steps: {}".format(len(steps)))
    print()


@click.group(name="deepsea")
@click.option('-l', '--log-level', default='info',
              type=click.Choice(["info", "error", "debug", "silent"]),
              help="set log level (default: info)")
@click.option('--log-file', default='/var/log/deepsea.log',
              type=click.Path(dir_okay=False),
              help="the file path for the log to be stored (default: /var/log/deepsea.log)")
@click.version_option(pkg_resources.get_distribution('deepsea'), message="%(version)s")
def cli(log_level, log_file):
    """
    DeepSea CLI tool.

    Use this tool to visualize the execution progress of DeepSea, either by
    running the stages directly through "stage run" command, or by monitoring
    the salt-run execution using the "monitor" command.
    """
    Config.LOG_LEVEL = log_level
    Config.LOG_FILE_PATH = log_file


@click.command(name='monitor')
@click.option('--show-state-steps', is_flag=True, help="shows state visible steps progress")
@click.option('--show-dynamic-steps', is_flag=True, help="shows runtime generated steps")
@click.option('--simple-output', is_flag=True, help="minimalistic b&w output")
@requires_root_privileges
def monitor(show_state_steps, show_dynamic_steps, simple_output):
    """
    Starts DeepSea progress monitor.

    This allows to visualize DeepSea execution progress when running DS stages
    using salt-run commands in other terminal sessions.
    """
    _setup_logging()
    _run_monitor(show_state_steps, show_dynamic_steps, simple_output)


@click.group(short_help='stage related commands')
def stage():
    """
    CLI 'stage' group command
    """
    pass


@click.command(name='dry-run', short_help='show DeepSea stage steps')
@click.argument('stage_name', 'the DeepSea stage name')
@click.option('--hide-state-steps', is_flag=True,
              help="this will disable state files steps from being parsed")
@click.option('--only-visible-steps', is_flag=True,
              help="only show the steps that will generate events in the Salt Event Bus")
@click.option('--clear-cache', is_flag=True, help="clear steps cache")
@click.option('--no-cache', is_flag=True, help="don't store/use stage parsing results cache")
@requires_root_privileges
def stage_dryrun(stage_name, hide_state_steps, only_visible_steps, clear_cache, no_cache):
    """
    CLI 'stage dry-run' command
    """
    _setup_logging()
    if clear_cache:
        SLSParser.clean_cache(None)
    _run_show_stage_steps(stage_name, hide_state_steps, only_visible_steps, not no_cache)


@click.command(name='run', short_help='runs DeepSea stage')
@click.argument('stage_name', 'the DeepSea stage name')
@click.option('--hide-state-steps', is_flag=True, help="shows state visible steps progress")
@click.option('--hide-dynamic-steps', is_flag=True, help="shows runtime generated steps")
@click.option('--simple-output', is_flag=True, help="minimalistic b&w output")
@requires_root_privileges
def stage_run(stage_name, hide_state_steps, hide_dynamic_steps, simple_output):
    """
    Runs a DeepSea stage

    This command is equivalent to run:

        $ salt-run state.orch <stage_name>
    """
    _setup_logging()
    _validate_stage_file_exists(stage_name)

    ret = run_stage(stage_name, hide_state_steps, hide_dynamic_steps, simple_output)
    sys.exit(ret)


@click.group(name='salt-run')
def salt_run():
    """
    stage command alias
    """
    pass


@click.command(name='state.orch')
@click.argument('stage_name', 'the DeepSea stage name')
@click.option('--hide-state-steps', is_flag=True, help="shows state visible steps progress")
@click.option('--hide-dynamic-steps', is_flag=True, help="shows runtime generated steps")
@click.option('--simple-output', is_flag=True, help="minimalistic b&w output")
@requires_root_privileges
def state_orch(stage_name, hide_state_steps, hide_dynamic_steps, simple_output):
    """
    Runs a DeepSea stage

    This command is equivalent to run:

        $ salt-run state.orch <stage_name>
    """
    _setup_logging()
    _validate_stage_file_exists(stage_name)

    ret = run_stage(stage_name, hide_state_steps, hide_dynamic_steps, simple_output)
    sys.exit(ret)


def main():
    """
    CLI main function
    """
    cli.add_command(monitor)
    cli.add_command(stage)
    cli.add_command(salt_run)
    stage.add_command(stage_dryrun)
    stage.add_command(stage_run)
    salt_run.add_command(state_orch)
    # pylint: disable=E1120,E1123
    cli(prog_name='deepsea')
