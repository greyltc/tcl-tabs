
snit::type tabs::job::sample {
    # -manager is needed for internal purposes
    option -manager

    option -message -default "Hello world"

    constructor {args} {
        $self configurelist $args
    }

    method inputs {} {
        # if applicable, return a list of files that are used as input for the job
        return [list]
    }
   
    method outputs {} {
        # if applicable, return a list of files that are used as input for the job
        return [list]
    }
   
    method execute {} {
        puts [$self cget -message]
    }
}

