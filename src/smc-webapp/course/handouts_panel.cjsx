# SMC libraries
misc = require('smc-util/misc')
{defaults, required} = misc
{salvus_client} = require('../salvus_client')

# React Libraries
{React, rclass, rtypes} = require('../smc-react')
{Button, ButtonToolbar, ButtonGroup, Input, Row, Col, Panel, Table} = require('react-bootstrap')

# SMC and course components
course_funcs = require('./pfunctions')
styles = require('./styles')
{BigTime, FoldersToolbar} = require('./common')
{Icon, Tip, SearchInput, MarkdownInput} = require('../r_misc')

exports.HandoutsPanel = rclass
    displayName : 'Course-editor-HandoutsPanel'

    propTypes :
        project_id   : rtypes.string.isRequired
        all_handouts : rtypes.object.isRequired
        students     : rtypes.object.isRequired
        user_map     : rtypes.object.isRequired
        actions      : rtypes.object.isRequired
        store        : rtypes.object.isRequired
        project_actions : rtypes.object.isRequired

    getInitialState : ->
        show_deleted : false
        search          : ''      # Search value for filtering handouts

    # fuck yeah immutable.js (important because compute is potentially expensive)
    shouldComponentUpdate : (nextProps, nextState) ->
        if nextProps.all_handouts != @props.all_handouts or nextProps.students != @props.students
            return true
        if nextState.search != @state.search or nextState.show_deleted != @state.show_deleted
            return true
        return false

    # also used in assignments_panel
    compute_handouts_list : ->
        list = course_funcs.immutable_to_list(@props.all_handouts, 'handout_id')

        {list, num_omitted} = course_funcs.compute_match_list
            list        : list
            search_key  : 'path'
            search      : @state.search.trim()

        f = (a) -> [a.due_date ? 0, a.path?.toLowerCase()] # Changes for assignments
        compare = (a,b) => misc.cmp_array(f(a), f(b))

        {list, num_deleted} = course_funcs.order_list
            list             : list
            compare_function : compare
            include_deleted  : @state.show_deleted

        return {shown_handouts:list, num_omitted:num_omitted, num_deleted:num_deleted}

    render_show_deleted : (num_deleted) ->
        if @state.show_deleted
            <Button style={styles.show_hide_deleted} onClick={=>@setState(show_deleted:false)}>
                <Tip placement='left' title="Hide deleted" tip="Handouts are never really deleted.  Click this button so that deleted handouts aren't included at the bottom of the list.">
                    Hide {num_deleted} deleted handouts
                </Tip>
            </Button>
        else
            <Button style={styles.show_hide_deleted} onClick={=>@setState(show_deleted:true, search:'')}>
                <Tip placement='left' title="Show deleted" tip="Handouts are not deleted forever even after you delete them.  Click this button to show any deleted handouts at the bottom of the list of handouts.  You can then click on the handout and click undelete to bring the handout back.">
                    Show {num_deleted} deleted handouts
                </Tip>
            </Button>

    render : ->
        # Changes based on state changes so it just has to go in render
        {shown_handouts, num_omitted, num_deleted} = @compute_handouts_list()
        header =
            <FoldersToolbar
                search        = {@state.search}
                search_change = {(value) => @setState(search:value)}
                num_omitted   = {num_omitted}
                project_id    = {@props.project_id}
                items         = {@props.all_handouts}
                add_folders   = {(paths)=>paths.map(@props.actions.add_assignment)}
                item_name     = {"handout"}
                plural_item_name = {"handouts"}
            />

        <Panel header={header}>
            {for handout, i in shown_handouts
                <Handout background={if i%2==0 then "#eee"}  key={handout.assignment_id}
                        handout={@props.all_handouts.get(handout.assignment_id)} project_id={@props.project_id}
                        students={@props.students} user_map={@props.user_map} actions={@props.actions}
                        store={@props.store} open_directory={@props.project_actions.open_directory}
                />}
            {@render_show_deleted(num_deleted) if num_deleted > 0}
        </Panel>

exports.HandoutsPanel.Header = rclass
    propTypes :
        n : rtypes.number

    render: ->
        <Tip delayShow=1300
             title="Handouts"
             tip="This tab lists all of the handouts associated with your course.">
            <span>
                <Icon name="files-o"/> Handouts {if @props.n? then " (#{@props.n})" else ""}
            </span>
        </Tip>

Handout = rclass
    propTypes :
        handout             : rtypes.object
        background          : rtypes.string
        store               : rtypes.object
        actions             : rtypes.object
        open_directory      : rtypes.func     # open_directory(path)

    getInitialState : ->
        more : false
        confirm_delete : false

    open_handout_path : (e)->
        e.preventDefault()
        @props.open_directory(@props.handout.get('path'))

    # TODO: Add behavior like the identical function inside Assignment Component defined in assignments_panel
    render_more_header : ->
        <div>
            <Button onClick={@open_handout_path}>
                <Icon name="folder-open-o" /> Edit Handout
            </Button>
        </div>

    render_handout_notes : ->
        <Row key='note' style={styles.note}>
            <Col xs=2>
                <Tip title="Notes about this handout" tip="Record notes about this handout here. These notes are only visible to you, not to your students.  Put any instructions to students about handouts in a file in the directory that contains the handout.">
                    Private Handout Notes<br /><span style={color:"#666"}></span>
                </Tip>
            </Col>
            <Col xs=10>
                <MarkdownInput
                    rows          = 6
                    placeholder   = 'Private notes about this handout (not visible to students)'
                    default_value = {@props.handout.get('note')}
                    on_save       = {(value)=>@props.actions.set_assignment_note(@props.handout, value)}
                />
            </Col>
        </Row>

    render_more : ->
        <Row key='more'>
            <Col sm=12>
                <Panel header={@render_more_header()}>
                    <StudentListForHandout handout={@props.handout} students={@props.students}
                        user_map={@props.user_map} store={@props.store}, actions={@props.actions}/>
                    {@render_handout_notes()}
                </Panel>
            </Col>
        </Row>

    render : ->
        <Row style={if @state.more then styles.selected_entry else styles.entry}>
            <Col xs=12>
                <Row key='summary' style={backgroundColor:@props.background}>
                    <Col md=6>
                        <h5>
                            <a href='' onClick={(e)=>e.preventDefault();@setState(more:not @state.more)}>
                                <Icon style={marginRight:'10px'}
                                      name={if @state.more then 'caret-down' else 'caret-right'} />
                                <span>
                                    {misc.trunc_middle(@props.handout.get('path'), 80)}
                                    {<b> (deleted)</b> if @props.handout.get('deleted')}
                                </span>
                            </a>
                        </h5>
                    </Col>
                    <Col md=6>
                        <Tip placement='left' title="Distribute" tip="Copy this folder to all your students projects.">
                            <Button>Distribute</Button>/<Button>Re-distribute</Button>
                        </Tip>
                    </Col>
                </Row>
                {@render_more() if @state.more}
            </Col>
        </Row>

StudentListForHandout = rclass
    propTypes :
        user_map : rtypes.object
        students : rtypes.object
        handout : rtypes.object
        store    : rtypes.object
        actions  : rtypes.object

    render_students : ->
        v = course_funcs.immutable_to_list(@props.students, 'student_id')
        # fill in names, for use in sorting and searching (TODO: caching)
        v = (x for x in v when not x.deleted)
        for x in v
            user = @props.user_map.get(x.account_id)
            if user?
                x.first_name = user.get('first_name')
                x.last_name  = user.get('last_name')
                x.name = x.first_name + ' ' + x.last_name
                x.sort = (x.last_name + ' ' + x.first_name).toLowerCase()
            else if x.email_address?
                x.name = x.sort = x.email_address.toLowerCase()

        v.sort (a,b) ->
            return misc.cmp(a.sort, b.sort)

        for x in v
            @render_student_info(x.student_id, x)

    render_student_info : (id, student) ->
        <StudentHandoutInfo
            key = {id}
            actions = {@props.actions}
            info = {@props.store.student_assignment_info(id, @props.handout)}
            title = {misc.trunc_middle(@props.store.get_student_name(id), 40)}
            student = {id}
            handout = {@props.handout}
        />

    render : ->
        <div>
            <StudentHandoutInfoHeader
                key        = 'header'
                title      = "Student"
            />
            {@render_students()}
        </div>

StudentHandoutInfoHeader = rclass
    displayName : "CourseEditor-StudentHandoutInfoHeader"

    propTypes :
        title      : rtypes.string.isRequired

    render_col: (step_number, key, width) ->
        switch key
            when 'last_handout'
                title = 'Distribute to Student'
                tip   = 'This column gives the status of making homework available to students, and lets you copy homework to one student at a time.'
            when 'collect'
                title = 'Another option'
                tip   = 'This column gives status information about collecting homework from students, and lets you collect from one student at a time.'
            when 'grade'
                title = '???'
                tip   = 'Record homework grade" tip="Use this column to record the grade the student received on the handout. Once the grade is recorded, you can return the handout.  You can also export grades to a file in the Settings tab.'

            when 'return_graded'
                title = 'Hmmmm?'
                tip   = 'This column gives status information about when you returned homework to the students.  Once you have entered a grade, you can return the handout.'
                placement = 'left'
        <Col md={width} key={key}>
            <Tip title={title} tip={tip}>
                <b>{step_number}. {title}</b>
            </Tip>
        </Col>


    render_headers: ->
        w = 3
        <Row>
            {@render_col(1, 'last_handout', w)}
            {@render_col(2, 'collect', w)}
            {@render_col(3, 'grade', w)}
            {@render_col(4, 'return_graded', w)}
        </Row>

    render : ->
        <Row style={borderBottom:'2px solid #aaa'} >
            <Col md=2 key='title'>
                <Tip title={@props.title} tip={if @props.title=="Handout" then "This column gives the directory name of the handout." else "This column gives the name of the student."}>
                    <b>{@props.title}</b>
                </Tip>
            </Col>
            <Col md=10 key="rest">
                {@render_headers()}
            </Col>
        </Row>

StudentHandoutInfo = rclass
    displayName : "CourseEditor-StudentHandoutInfo"

    propTypes :
        actions    : rtypes.object.isRequired
        info       : rtypes.object.isRequired
        title      : rtypes.oneOfType([rtypes.string,rtypes.object]).isRequired
        student    : rtypes.oneOfType([rtypes.string,rtypes.object]).isRequired # required string (student_id) or student immutable js object
        handout    : rtypes.oneOfType([rtypes.string,rtypes.object]).isRequired # required string (handout_id) or handout immutable js object

    open : (type, handout_id, student_id) ->
        @props.actions.open_assignment(type, handout_id, student_id)

    copy : (type, handout_id, student_id) ->
        @props.actions.copy_assignment(type, handout_id, student_id)

    stop : (type, handout_id, student_id) ->
        @props.actions.stop_copying_assignment(type, handout_id, student_id)

    render_last_time : (name, time) ->
        <div key='time' style={color:"#666"}>
            (<BigTime date={time} />)
        </div>

    render_open_recopy_confirm : (name, open, copy, copy_tip, open_tip, placement) ->
        key = "recopy_#{name}"
        if @state[key]
            v = []
            v.push <Button key="copy_confirm" bsStyle="danger" onClick={=>@setState("#{key}":false);copy()}>
                <Icon name="share-square-o" rotate={"180" if name.indexOf('ollect')!=-1}/> Yes, {name.toLowerCase()} again
            </Button>
            v.push <Button key="copy_cancel" onClick={=>@setState("#{key}":false);}>
                 Cancel
            </Button>
            return v
        else
            <Button key="copy" bsStyle='warning' onClick={=>@setState("#{key}":true)}>
                <Tip title={name} placement={placement}
                    tip={<span>{copy_tip}</span>}>
                    <Icon name='share-square-o' rotate={"180" if name.indexOf('ollect')!=-1}/> {name}...
                </Tip>
            </Button>

    render_open_recopy : (name, open, copy, copy_tip, open_tip) ->
        placement = if name == 'Return' then 'left' else 'right'
        <ButtonToolbar key='open_recopy'>
            {@render_open_recopy_confirm(name, open, copy, copy_tip, open_tip, placement)}
            <Button key='open'  onClick={open}>
                <Tip title="Open handout" placement={placement} tip={open_tip}>
                    <Icon name="folder-open-o" /> Open
                </Tip>
            </Button>
        </ButtonToolbar>

    render_open_copying : (name, open, stop) ->
        if name == "Return"
            placement = 'left'
        <ButtonGroup key='open_copying'>
            <Button key="copy" bsStyle='success' disabled={true}>
                <Icon name="circle-o-notch" spin /> {name}ing
            </Button>
            <Button key="stop" bsStyle='danger' onClick={stop}>
                <Icon name="times" />
            </Button>
            <Button key='open'  onClick={open}>
                <Icon name="folder-open-o" /> Open
            </Button>
        </ButtonGroup>

    render_copy : (name, copy, copy_tip) ->
        if name == "Return"
            placement = 'left'
        <Tip key="copy" title={name} tip={copy_tip} placement={placement} >
            <Button onClick={copy} bsStyle={'primary'}>
                <Icon name="share-square-o" rotate={"180" if name.indexOf('ollect')!=-1}/> {name}
            </Button>
        </Tip>

    render_error : (name, error) ->
        if typeof(error) != 'string'
            error = misc.to_json(error)
        if error.indexOf('No such file or directory') != -1
            error = 'Somebody may have moved the folder that should have contained the handout.\n' + error
        else
            error = "Try to #{name.toLowerCase()} again:\n" + error
        <ErrorDisplay key='error' error={error} style={maxHeight: '140px', overflow:'auto'}/>

    render_last : (name, obj, type, info, enable_copy, copy_tip, open_tip) ->
        open = => @open(type, info.assignment_id, info.student_id)
        copy = => @copy(type, info.assignment_id, info.student_id)
        stop = => @stop(type, info.assignment_id, info.student_id)
        obj ?= {}
        v = []
        if enable_copy
            if obj.start
                v.push(@render_open_copying(name, open, stop))
            else if obj.time
                v.push(@render_open_recopy(name, open, copy, copy_tip, open_tip))
            else
                v.push(@render_copy(name, copy, copy_tip))
        if obj.time
            v.push(@render_last_time(name, obj.time))
        if obj.error
            v.push(@render_error(name, obj.error))
        return v

    render : ->
        width = 12
        <Row style={borderTop:'1px solid #aaa', paddingTop:'5px', paddingBottom: '5px'}>
            <Col md=2 key="title">
                {@props.title}
            </Col>
            <Col md=10 key="rest">
                <Row>
                    <Col md={width} key='last_handout'>
                        {@render_last('Distribute', @props.info.last_assignment, 'assigned', @props.info, true,
                           "Copy the handout from your project to this student's project.",
                           "Open the student's copy of this handout directly in their project.  You will be able to see them type, chat with them, answer questions, etc.")}
                    </Col>
                </Row>
            </Col>
        </Row>