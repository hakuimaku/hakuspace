function fish_greeting
    set -l messages \
        ":) - Ready to cook some code." \
        ":( - Another day, another bug." \
        ":D - Let's build something awesome!" \
        ":v - System up. Don't break anything." \
        ":p - Easy peasy lemon squeezy." \
        "XD - Bro really opened terminal again." \
        ":> - Time to execute." \
        ":< - Please no segmentation fault today." \
        ":3 - Feelin' good, let's code!"

    set -l random_message (random choice $messages)

    set_color --italics brwhite
    echo "  $random_message"
    set_color normal
end