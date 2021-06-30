import slackweb
import datetime
import argparse

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Program parameters needed on this application')
    parser.add_argument('--slack_url', required=True, type=str, help='Slack webhook URL')
    parser.add_argument('--message', required=True, type=str, help='Text message')
    args = parser.parse_args()

    dt_now = datetime.datetime.now()

    slack = slackweb.Slack(url=args.slack_url)
    slack.notify(text="{} at {}.".format(args.message, dt_now))