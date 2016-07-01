##############################################################################
#
# SageMathCloud: A collaborative web-based interface to Sage, IPython, LaTeX and the Terminal.
#
#    Copyright (C) 2015, William Stein
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

###
Chat
###

# standard non-SMC libraries
immutable = require('immutable')

# SMC libraries
{Avatar, UsersViewingDocument} = require('./profile')
misc = require('smc-util/misc')
misc_page = require('./misc_page')
{defaults, required} = misc
{Markdown, TimeAgo, Tip} = require('./r_misc')
{salvus_client} = require('./salvus_client')
{synchronized_db} = require('./syncdb')

{alert_message} = require('./alerts')

# React libraries
{React, ReactDOM, rclass, rtypes, Actions, Store, Redux}  = require('./smc-react')
{Icon, Loading, TimeAgo} = require('./r_misc')
{Button, Col, Grid, Input, ListGroup, ListGroupItem, Panel, Row, ButtonGroup} = require('react-bootstrap')

{User} = require('./users')

redux_name = (project_id, path) ->
    return "editor-#{project_id}-#{path}"

class ChatActions extends Actions
    _syncdb_change: (changes) =>
        m = messages = @redux.getStore(@name).get('messages')
        for x in changes
            if x.insert
                messages = messages.set(x.insert.date - 0, immutable.fromJS(x.insert))
            else if x.remove
                messages = messages.delete(x.remove.date - 0)
        if m != messages
            @setState(messages: messages)

    send_chat: (mesg) =>
        mesg = misc_page.sanitize_html(mesg)
        if not @syncdb?
            # TODO: give an error or try again later?
            return
        @syncdb.update
            set :
                sender_id : @redux.getStore('account').get_account_id()
                event     : "chat"
                payload   : {content: mesg}
            where :
                date: salvus_client.server_time()
        @syncdb.save()

    set_input: (input) =>
        @setState(input:input)

    save_scroll_state: (position, height) =>
        if height != 0
            @setState(position:position, height:height)

# boilerplate setting up actions, stores, sync'd file, etc.
syncdbs = {}
exports.init_redux = init_redux = (redux, project_id, filename) ->
    name = redux_name(project_id, filename)
    if redux.getActions(name)?
        return  # already initialized
    actions = redux.createActions(name, ChatActions)
    store   = redux.createStore(name, {input:''})

    synchronized_db
        project_id    : project_id
        filename      : filename
        sync_interval : 0
        cb            : (err, syncdb) ->
            if err
                alert_message(type:'error', message:"unable to open #{@filename}")
            else if not syncdb.valid_data
                alert_message(type:'error', message:"json in #{@filename} is broken")
            else
                v = {}
                for x in syncdb.select()
                    v[x.date - 0] = x
                actions.setState(messages : immutable.fromJS(v))
                syncdb.on('change', actions._syncdb_change)
                store.syncdb = actions.syncdb = syncdb

Message = rclass
    displayName: "Message"

    propTypes:
        # example message object
        # {"sender_id":"f117c2f8-8f8d-49cf-a2b7-f3609c48c100","event":"chat","payload":{"content":"l"},"date":"2015-08-26T21:52:51.329Z"}
        message        : rtypes.object.isRequired  # immutable.js message object
        account_id     : rtypes.string.isRequired
        sender_name    : rtypes.string
        user_map       : rtypes.object
        project_id     : rtypes.string    # optional -- improves relative links if given
        file_path      : rtypes.string    # optional -- (used by renderer; path containing the chat log)
        font_size      : rtypes.number
        show_avatar    : rtypes.bool
        is_prev_sender : rtypes.bool
        is_next_sender : rtypes.bool

    shouldComponentUpdate: (next) ->
        return @props.message != next.message or
               @props.user_map != next.user_map or
               @props.account_id != next.account_id or
               @props.show_avatar != next.show_avatar or
               @props.is_prev_sender != next.is_prev_sender or
               @props.is_next_sender != next.is_next_sender or
               ((not @props.is_prev_sender) and (@props.sender_name != next.sender_name))

    sender_is_viewer: ->
        @props.account_id == @props.message.get('sender_id')

    get_timeago: ->
        <div className="pull-right small" style={color:'#888', marginTop:'-8px', marginBottom:'1px'}>
            <TimeAgo date={new Date(@props.message.get('date'))} />
        </div>

    show_user_name: ->
        <div className={"small"} style={color:'#888', marginBottom:'1px', marginLeft:'10px'}>
            {@props.sender_name}
        </div>

    avatar_column: ->
        account = @props.user_map?.get(@props.message.get('sender_id'))?.toJS()
        if @props.is_prev_sender
            margin_top = '5px'
        else
            margin_top = '27px'

        if @sender_is_viewer()
            textAlign = 'left'
            marginRight = '11px'
        else
            textAlign = 'right'
            marginLeft = '11px'

        style =
            display       : "inline-block"
            marginTop     : margin_top
            marginLeft    : marginLeft
            marginRight   : marginRight
            padding       : '0px'
            textAlign     : textAlign
            verticalAlign : "middle"
            width         : '4%'

        # TODO: do something better when we don't know the user (or when sender account_id is bogus)
        <Col key={0} xsHidden={true} sm={1} style={style} >
            <div>
                {<Avatar account={account} /> if account? and @props.show_avatar }
            </div>
        </Col>

    content_column: ->
        value = @props.message.get('payload')?.get('content') ? ''

        if @sender_is_viewer()
            color = '#f5f5f5'
        else
            color = '#fff'

        # smileys, just for fun.
        value = misc.smiley
            s: value
            wrap: ['<span class="smc-editor-chat-smiley">', '</span>']
        value = misc_page.sanitize_html(value)

        font_size = "#{@props.font_size}px"

        if @props.show_avatar
            marginBottom = "20px" # the default value actually..
        else
            marginBottom = "3px"

        if not @props.is_prev_sender and @sender_is_viewer()
            marginTop = "17px"

        if not @props.is_prev_sender and not @props.is_next_sender
            borderRadius = '10px 10px 10px 10px'
        else if not @props.is_prev_sender
            borderRadius = '10px 10px 5px 5px'
        else if not @props.is_next_sender
            borderRadius = '5px 5px 10px 10px'

        <Col key={1} xs={10} sm={9}>
            {@show_user_name() if not @props.is_prev_sender and not @sender_is_viewer()}
            <Panel style={background:color, wordWrap:"break-word", marginBottom: marginBottom, marginTop: marginTop, borderRadius: borderRadius}>
                <ListGroup fill>
                    <ListGroupItem style={background:color, fontSize: font_size, borderRadius: borderRadius}>
                        <Markdown value={value}
                                  project_id={@props.project_id}
                                  file_path={@props.file_path} />
                        {@get_timeago()}
                    </ListGroupItem>
                </ListGroup>
            </Panel>
        </Col>

    blank_column:  ->
        <Col key={2} xs={2}></Col>

    render: ->
        cols = [@avatar_column(), @content_column(), @blank_column()]
        # mirror right-left for sender's view
        if @sender_is_viewer()
            cols = cols.reverse()
        <Row>
            {cols}
        </Row>

ChatLog = rclass
    displayName: "ChatLog"

    propTypes:
        messages   : rtypes.object.isRequired   # immutable js map {timestamps} --> message.
        user_map   : rtypes.object              # immutable js map {collaborators} --> account info
        account_id : rtypes.string
        project_id : rtypes.string   # optional -- used to render links more effectively
        file_path  : rtypes.string   # optional -- ...
        font_size  : rtypes.number

    shouldComponentUpdate: (next) ->
        return @props.messages != next.messages or @props.user_map != next.user_map or @props.account_id != next.account_id

    list_messages: ->
        is_next_message_sender = (index, dates, messages) ->
            if index + 1 == dates.length
                return false
            current_message = messages.get(dates[index])
            next_message = messages.get(dates[index + 1])
            return current_message.get('sender_id') == next_message.get('sender_id')

        is_prev_message_sender = (index, dates, messages) ->
            if index == 0
                return false
            current_message = messages.get(dates[index])
            prev_message = messages.get(dates[index - 1])
            return current_message.get('sender_id') == prev_message.get('sender_id')

        sorted_dates = @props.messages.keySeq().sort(misc.cmp_Date).toJS()
        v = []
        for date, i in sorted_dates
            sender_account = @props.user_map.get(@props.messages.get(date).get('sender_id'))
            if sender_account?
                sender_name = sender_account.get('first_name') + ' ' + sender_account.get('last_name')
            else
                sender_name = "Unknown"

            v.push <Message key={date}
                     account_id  = {@props.account_id}
                     user_map    = {@props.user_map}
                     message     = {@props.messages.get(date)}
                     project_id  = {@props.project_id}
                     file_path   = {@props.file_path}
                     font_size   = {@props.font_size}
                     is_prev_sender   = {is_prev_message_sender(i, sorted_dates, @props.messages)}
                     is_next_sender   = {is_next_message_sender(i, sorted_dates, @props.messages)}
                     show_avatar      = {not is_next_message_sender(i, sorted_dates, @props.messages)}
                     sender_name      = {sender_name}
                    />
        return v

    render: ->
        <div>
            {@list_messages()}
        </div>

ChatRoom = (name) -> rclass
    displayName: "ChatRoom"

    reduxProps :
        "#{name}" :
            messages    : rtypes.immutable
            input       : rtypes.string
            position    : rtypes.number
            height      : rtypes.number
        users :
            user_map : rtypes.immutable
        account :
            account_id : rtypes.string
            font_size  : rtypes.number
        file_use :
            file_use : rtypes.immutable

    propTypes :
        redux       : rtypes.object
        name        : rtypes.string.isRequired
        project_id  : rtypes.string.isRequired
        file_use_id : rtypes.string.isRequired
        path        : rtypes.string

    getInitialState: ->
        input : ''

    keydown : (e) ->
        if e.keyCode==27 # ESC
            e.preventDefault()
            @clear_input()
        else if e.keyCode==13 and not e.shiftKey # 13: enter key
            @scroll_to_bottom()
            e.preventDefault()
            mesg = @refs.input.getValue()
            # block sending empty messages
            if mesg.length? and mesg.trim().length >= 1
                @props.redux.getActions(@props.name).send_chat(mesg)
                @clear_input()

    clear_input: ->
        @props.redux.getActions(@props.name).set_input('')

    render_input: ->
        tip = <span>
            You may enter (Github flavored) markdown here and include Latex mathematics in $ signs.  In particular, use # for headings, > for block quotes, *'s for italic text, **'s for bold text, - at the beginning of a line for lists, back ticks ` for code, and URL's will automatically become links.   Press shift+enter for a newline without submitting your chat.
        </span>

        return <div>
            <Input
                autoFocus
                rows      = 4
                type      = 'textarea'
                ref       = 'input'
                onKeyDown = {@keydown}
                value     = {@props.input}
                onClick   = {=>@props.redux.getActions('file_use').mark_file(@props.project_id, @props.path, 'read')}
                onChange  = {(value)=>@props.redux.getActions(@props.name).set_input(@refs.input.getValue())}
                />
            <div style={marginTop: '-15px', marginBottom: '15px', color:'#666'}>
                <Tip title='Use Markdown' tip={tip}>
                    Shift+Enter for newline.
                    Format using <a href='https://help.github.com/articles/markdown-basics/' target='_blank'>Markdown</a>.
                    Emoticons: {misc.emoticons}.
                </Tip>
            </div>
        </div>

    chat_log_style:
        overflowY    : "auto"
        overflowX    : "hidden"
        height       : "60vh"
        margin       : "0"
        padding      : "0"
        paddingRight : "10px"

    chat_input_style:
        height       : "0vh"
        margin       : "0"
        padding      : "0"
        marginTop    : "5px"

    #should not be called if not in chat tab
    scroll_to_bottom: ->
        if @refs.log_container?
            node = ReactDOM.findDOMNode(@refs.log_container)
            node.scrollTop = node.scrollHeight
            @props.redux.getActions(@props.name).save_scroll_state(node.scrollTop, node.scrollTop)
            console.log('stats: ', @props.position, @props.height)
            @_scrolled = false

    scroll_to_position: ->
        if @refs.log_container?
            @_scrolled = true
            node = ReactDOM.findDOMNode(@refs.log_container)
            node.scrollTop = @props.position

    #should not be called if not in chat tab
    on_scroll: (e) ->
        @_scrolled = true
        node = ReactDOM.findDOMNode(@refs.log_container)
        @props.redux.getActions(@props.name).save_scroll_state(node.scrollTop, node.scrollTop)
        console.log('stats: ', @props.position, @props.height)
        e.preventDefault()

    componentDidMount: ->
        @scroll_to_position()

    componentWillReceiveProps: (next) ->
        if @props.messages != next.messages and @props.position == @props.height
            @_scrolled = false

    #componentWillUpdate: (next_props) ->
        #if @refs.log_container
            #node = ReactDOM.findDOMNode(@refs.log_container)
            #if (node.scrollHeight + 10 > node.scrollTop + node.offsetHeight > node.scrollHeight - 10)
                #@_scrolled = false

    componentDidUpdate: ->
        if not @_scrolled
            @scroll_to_bottom()

    show_files : ->
        @props.redux?.getProjectActions(@props.project_id).set_focused_page('project-file-listing')

    show_timetravel: ->
        @props.redux?.getProjectActions(@props.project_id).open_file
            path               : misc.history_path(@props.path)
            foreground         : true
            foreground_project : true

    render : ->
        if not @props.messages? or not @props.redux?
            return <Loading/>
        <Grid>
            <Row style={marginBottom:'5px'}>
                <Col xs={4}>
                    <Button className='smc-small-only' bsSize='large'
                            onClick={@show_files}><Icon name='toggle-up'/> Files
                    </Button>
                </Col>
                <Col xs={4}>
                    <div style={float:'right'}>
                        <UsersViewingDocument
                              file_use_id = {@props.file_use_id}
                              file_use    = {@props.file_use}
                              account_id  = {@props.account_id}
                              user_map    = {@props.user_map} />
                    </div>
                </Col>
                <Col xs={4}>
                    <ButtonGroup style={float:'right'}>
                        <Button onClick={@show_timetravel} bsStyle='info'>
                            <Icon name='history'/> TimeTravel
                        </Button>
                        <Button onClick={@scroll_to_bottom}>
                            <Icon name='arrow-down'/> Scroll to Bottom
                        </Button>
                    </ButtonGroup>
                </Col>
            </Row>
            <Row>
                <Col md={12}>
                    <Panel style={@chat_log_style} ref='log_container' onScroll={@on_scroll} >
                        <ChatLog
                            messages     = {@props.messages}
                            account_id   = {@props.account_id}
                            user_map     = {@props.user_map}
                            project_id   = {@props.project_id}
                            font_size    = {@props.font_size}
                            file_path    = {if @props.path? then misc.path_split(@props.path).head} />
                    </Panel>
                </Col>
            </Row>
            <Row>
                <Col md={12}>
                    <div style={@chat_input_style}>
                        {@render_input()}
                    </div>
                </Col>
            </Row>
        </Grid>

# boilerplate fitting this into SMC below

render = (redux, project_id, path) ->
    name = redux_name(project_id, path)
    file_use_id = require('smc-util/schema').client_db.sha1(project_id, path)
    C = ChatRoom(name)
    <Redux redux={redux}>
        <C redux={redux} name={name} project_id={project_id} path={path} file_use_id={file_use_id} />
    </Redux>

exports.render = (project_id, path, dom_node, redux) ->
    init_redux(redux, project_id, path)
    ReactDOM.render(render(redux, project_id, path), dom_node)

exports.hide = (project_id, path, dom_node, redux) ->
    ReactDOM.unmountComponentAtNode(dom_node)

exports.show = (project_id, path, dom_node, redux) ->
    ReactDOM.render(render(redux, project_id, path), dom_node)

exports.free = (project_id, path, dom_node, redux) ->
    fname = redux_name(project_id, path)
    store = redux.getStore(fname)
    if not store?
        return
    ReactDOM.unmountComponentAtNode(dom_node)
    store.syncdb?.destroy()
    delete store.state
    # It is *critical* to first unmount the store, then the actions,
    # or there will be a huge memory leak.
    redux.removeStore(fname)
    redux.removeActions(fname)


